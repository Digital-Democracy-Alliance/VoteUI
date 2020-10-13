import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

const ETHEREUM_ADDRESS = "ethereumAddress";
const PARAMS = "params";
const METHOD = "method";
const BASE_URL = "";
const METHOD_SIGNUP = "signup";

// The service responsible for networking requests
@lazySingleton
class UserApi {
  var client = new http.Client();
  var endpoint = 'https://api.blockchain.suzuka.flux.party/members/api';

  Future<dynamic> signup(String ethereumAddress) async {
    var body = Map<String, dynamic>();

    /*{
      method: "signup",
      data: {
        pubkey: string
      }
    }*/
    body[METHOD] = METHOD_SIGNUP;
    body[PARAMS] = Map<String, dynamic>();
    body[PARAMS][ETHEREUM_ADDRESS] = ethereumAddress;
    body[PARAMS]['unsafeChecksum'] = true;
    var bodyText = jsonEncode(body);
    //print(bodyText);

    http.Response response = await client.post(endpoint,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: bodyText);
    return response.body;
  }
}
