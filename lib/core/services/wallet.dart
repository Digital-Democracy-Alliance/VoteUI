/// Wallet service
///
/// The wallet is loaded on demand, and not kept in memory. This is to make illegal access to the keys more difficult.
/// -- Comment: I'm not sure keeping it out of memory makes it much harder to access the keys; we shouldn't implement something like this if the thread model also includes e.g. a phone with a rootkit. -MK
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:dartz/dartz.dart';
import 'package:hex/hex.dart';
//import 'package:flutter/services.dart' as services;
import 'package:http/http.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web3dart/web3dart.dart';

const WALLET_FILE_NAME = "wallet.json";
const TEMPORARY_PASSWORD = "4%8=)l_L210920A@g,";
const ETH_HD_DERIVATION_PATH = "m/44'/60'/0'/0/0";

Logger log = Logger();

class WalletMissingException implements Exception {
  @override
  String toString() {
    return "Wallet file is missing";
  }
}

@lazySingleton
class WalletService {
  Option<String> _walletDirectoryPath = None();
  void set walletDirectoryPath(Option<String> wdp) {
    _walletDirectoryPath = wdp;
  }

  /// Instantiate the service.
  /// @param _walletDirectoryPath The path of the directory to be used for storing the wallet file.
  WalletService();

  /// Create a new wallet and save it to the wallet file.
  /// If a list of strings is supplied as the parameter [words], they are used to generate the private key via BIP-39
  /// Otherwise, a random private key is generated from scratch.
  Future<Wallet> make({List<String> /*?*/ words, String /*?*/ hex}) async {
    var rand = Random.secure();

    //Use mnemonic words if supplied, otherwise create a random key
    EthPrivateKey ethKey;
    if (words != null) {
      ethKey = _makePrivKeyFromWords(words);
    } else if (hex != null) {
      ethKey = EthPrivateKey.fromHex(hex);
    } else {
      ethKey = EthPrivateKey.createRandom(rand);
    }

    //Make a wallet from the key
    var wallet = Wallet.createNew(ethKey, TEMPORARY_PASSWORD, rand);

    log.i(
        "created wallet with address: ${await wallet.privateKey.extractAddress()}");
    //Save it to the wallet file and return it
    await save(wallet);
    log.i("saved wallet to disk.");
    return wallet;
  }

  //This can be used to allow the user to record their key.
  //Pass the result from this method into make()
  static List<String> makeRandomWords() {
    String words = bip39.generateMnemonic();
    return words.split(" ");
  }

  ///Make a private key, given a list of words
  static EthPrivateKey _makePrivKeyFromWords(List<String> words) {
    //Make into a string
    var mnemonic = words.reduce((value, element) => "$value $element");

    // Make a seed from a list of words
    String seed = bip39.mnemonicToSeedHex(mnemonic);

    // Make a BIP32 for an Ethereum key
    bip32.BIP32 root =
        bip32.BIP32.fromSeed(Uint8List.fromList(HEX.decode(seed)));
    bip32.BIP32 child = root.derivePath(ETH_HD_DERIVATION_PATH);

    // Make into an EthPrivateKey
    String privateKey = HEX.encode(child.privateKey);
    return EthPrivateKey.fromHex(privateKey);
  }

  /// Read wallet from the wallet file.
  /// TODO: set allowCreation to false once we figure out a fix for on-load
  /// exception
  Future<Wallet> load(
      {bool allowCreation = true, bool allowPreexistingFile = true}) async {
    log.i("checking for walletExists");
    var _walletExists = await walletExists();
    log.i("got walletExists=${_walletExists}");

    if (_walletExists && allowPreexistingFile) {
      log.i("Loading wallet as walletExists returned true");
      String walletContent = (await walletFile()).readAsStringSync();
      return Wallet.fromJson(walletContent, TEMPORARY_PASSWORD);
    } else if (allowCreation) {
      log.i("Returning wallet via .make() as allowCreation=${allowCreation}");
      return await this.make();
    } else {
      log.i(
          "Wallet file missing but allowCreation=false -- throwing exception");
      throw WalletMissingException();
    }
  }

  /// Write a wallet to the wallet file.
  Future<bool> save(Wallet wallet) async {
    try {
      var file = await walletFile();
      var file2 = (await walletFile()).writeAsStringSync(wallet.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Web3Client> makeEthClient() async {
    const HTTPS_ETH_NODE_URL = "http://54.153.142.251:8545";
    //"https://kovan.infura.io/v3/663bcd65903948a6b53cd96866fc1a4a";
    var ethClient = new Web3Client(HTTPS_ETH_NODE_URL, new Client());
    return ethClient;
  }

  Future<EtherAmount> balance() async {
    //try {
    var ethClient = await makeEthClient();
    var address = await ethereumAddress();
    print("Getting balance of " + address.toString());
    return await ethClient.getBalance(address);
    //} catch (e) {
    //  return EtherAmount.zero();
    //}
  }

  /// Returns true if the wallet file exists.
  Future<bool> walletExists() async {
    return (await walletFile()).existsSync();
  }

  /// Delete the wallet file.
  Future<bool> delete() async {
    try {
      await (await walletFile()).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<EthereumAddress> ethereumAddress() async {
    var wallet = await load();
    return await wallet.privateKey.extractAddress();
  }

  /// The file handle for the file used to store the wallet object.
  Future<File> walletFile() async {
    // note: only call getApplicationDocumentsDirectory if we do _not_ have a _walletDirectoryPath set.

    // regarding getApplicationDocumentsDirectory
    // > Path to a directory where the application may place data that is user-generated, or that cannot otherwise be recreated by your application.
    // > On iOS, this uses the NSDocumentDirectory API. Consider using getApplicationSupportDirectory instead if the data is not user-generated.
    //var appDocsDir = await getApplicationDocumentsDirectory();

    // comment: we should switch to getApplicationSupportDirectory when possible, I think, but it wasn't the issue with the macos/ios tests.

    // regarding getApplicationSupportDirectory
    // > Use this for files you don???t want exposed to the user. Your app should not use this directory for user data files.
    //var appDocsDir = await getApplicationSupportDirectory();
    // note: might be better to use getLibraryDirectory on iOS

    String wp = await _walletDirectoryPath
        .map((a) => Future.value(a))
        .getOrElse(() async => (await getApplicationDocumentsDirectory()).path);
    return File('${wp}/${WALLET_FILE_NAME}');
  }

  Future<String> sendTransaction(DeployedContract contract,
      ContractFunction contractFunction, List<dynamic> params) async {
    var ethClient = await makeEthClient();
    var wallet = await load();

    return await ethClient.sendTransaction(
        wallet.privateKey,
        Transaction.callContract(
          contract: contract,
          function: contractFunction,
          parameters: params,
        ),
        fetchChainIdFromNetworkId: true);
  }

  Future<dynamic> call(DeployedContract contract,
      ContractFunction contractFunction, List<dynamic> params) async {
    var ethClient = await makeEthClient();
    return await ethClient.call(
      contract: contract,
      function: contractFunction,
      params: params,
    );
  }
}
