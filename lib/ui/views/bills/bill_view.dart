import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:voting_app/core/consts.dart';
import 'package:voting_app/core/enums/viewstate.dart';
import 'package:voting_app/core/models/bill.dart';
import 'package:voting_app/core/models/block_chain_data.dart';
import 'package:voting_app/core/viewmodels/bill_model.dart';
import 'package:voting_app/locator.dart';
import 'package:voting_app/ui/styles.dart';
import 'package:voting_app/ui/views/base_view.dart';
import 'package:voting_app/ui/views/bills/pdf_viewer.dart';
import 'package:voting_app/ui/widgets/house_icon_widget.dart';
import 'package:voting_app/ui/widgets/pie_chart.dart';
import 'package:voting_app/ui/widgets/voting_status_widget.dart';
import 'package:voting_app/ui/widgets/voting_widgets.dart';

class BillPage extends StatefulWidget {
  /* Not sure how we'd instantiate this. -MK
  */
  @override
  _BillPageState createState() => _BillPageState();
  /*
   */

  final Bill bill;

  BillPage({required Key key, required this.bill}) : super(key: key);
}

class _BillPageState extends State<BillPage> {
  BillModel billModel = locator<BillModel>();
  String? _vote;
  Box<Bill> billsBox = Hive.box<Bill>(HIVE_BILLS);
  Box<BlockChainData> blockChainData =
      Hive.box<BlockChainData>(HIVE_BLOCKCHAIN_DATA);
  late BlockChainData completeBlockChainData;

  _BillPageState() {
    this.completeBlockChainData = this
        .blockChainData
        .values
        .where((bill) => bill.id == widget.bill.id)
        .toList()
        .first;
  }

  Future getVote() async {
    /* do this in constructor  -MK
    // Get all bill data from Box
    List<BlockChainData> list = blockChainData.values
        .where((bill) => bill.id == widget.bill.id)
        .toList();
    completeBlockChainData = list[0];
     */

    var vote = await billModel.hasVoted(widget.bill.id);
    vote.map((v) => setState(() {
          _vote = v;
        }));
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    getVote();
  }

  @override
  Widget build(BuildContext context) {
    double dynamicMediumHeight = MediaQuery.of(context).size.height * 0.25;
    double dynamicLargeWidth = MediaQuery.of(context).size.width * 1;
    if (dynamicLargeWidth > appSizes.largeWidth) {
      dynamicLargeWidth = appSizes.largeWidth;
    }
    return BaseView<BillModel>(
      onModelReady: (model) => model.getBill(widget.bill.id),
      builder: (context, model, child) => Scaffold(
        appBar: AppBar(
          iconTheme: IconThemeData(color: appColors.text),
          elevation: 0,
          title: Text('Vote on Bill', style: appTextStyles.standard),
        ),
        body: model.state == ViewState.Busy
            ? Center(child: CircularProgressIndicator())
            : Center(
                child: Container(
                  width: dynamicLargeWidth,
                  child: ListView(
                    children: <Widget>[
                      PieWidget(
                        yes: model.billVoteResult.yes,
                        showValues: true,
                        sectionSpace: 10,
                        no: model.billVoteResult.no,
                        radius: 100,
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: 20.0, top: 20.0, left: 20.0),
                        child: HouseIconsWidget(bill: widget.bill, size: 25),
                      ),
                      Container(
                        width: dynamicLargeWidth,
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(25.0),
                                topRight: Radius.circular(25.0))),
                        padding: EdgeInsets.all(appSizes.standardPadding),
                        child: Column(
                          children: <Widget>[
                            Align(
                              child: VotingStatusWidget(
                                  bill: widget.bill, voted: false, size: 20),
                              alignment: Alignment.centerLeft,
                            ),
                            Align(
                              child: Padding(
                                padding:
                                    EdgeInsets.only(bottom: 20.0, top: 10.0),
                                child: Text(widget.bill.shortTitle,
                                    style:
                                        Theme.of(context).textTheme.headline5),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: 20.0),
                              child: Text(
                                widget.bill.summary,
                                style: Theme.of(context).textTheme.bodyText2,
                              ),
                            ),
                            Divider(),
                            RaisedButton(
                              padding: EdgeInsets.all(20.0),
                              child: Text("View Bill Text"),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<PdfPage>(
                                      builder: (context) => PdfPage(
                                          pdfUrl: widget.bill.textLinkPdf)),
                                );
                              },
                            ),
                            Container(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                "Text of the bill as introduced into the Parliament",
                                style: Theme.of(context).textTheme.bodyText2,
                              ),
                            ),
                            RaisedButton(
                              child: Text("View Explanatory Memoranda"),
                              padding: EdgeInsets.all(20.0),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<PdfPage>(
                                      builder: (context) => PdfPage(
                                          pdfUrl: widget.bill.emLinkPdf)),
                                );
                              },
                            ),
                            Container(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                "Accompanies and provides an explanation of the content of the introduced version (first reading) of the bill.",
                                style: Theme.of(context).textTheme.bodyText2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      VoteWidget(
                        data: completeBlockChainData.toBillChainData(),
                        vote: model.getVote,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
