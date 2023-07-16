import 'package:collection/collection.dart';
import 'package:decard/app_state.dart';
import 'package:decard/db.dart';
import 'package:flutter/material.dart';

import 'card_model.dart';
import 'card_view.dart';
import 'child.dart';
import 'common.dart';

class ChildResultsReport extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, Child child) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => ChildResultsReport(child: child)));
  }

  final Child child;

  const ChildResultsReport({required this.child, Key? key}) : super(key: key);

  @override
  State<ChildResultsReport> createState() => _ChildResultsReportState();
}

class _ChildResultsReportState extends State<ChildResultsReport> {
  bool _isStarting = true;

  late ChildTestResults _childTestResults;

  final _resultList = <TestResult>[];
  final Map<TestResult, int> _resultCardIDMap = {};
  final Map<int, CardData> _cardMap = {};

  final _displayResultList = <TestResult>[];

  final Map<String, int> _tagMap = {};
  String _selTag = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await widget.child.updateTestResultFromServer(appState.serverConnect);
    _childTestResults = await widget.child.testResults;

    await _refreshData();

    _refreshDisplayData();

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> _refreshData() async {
    _resultList.clear();
    _tagMap.clear();

    final Map<String, int> tagMap = {};

    for (var testResult in _childTestResults.resultList) {
      if (testResult.result) {
        _resultList.add(testResult);

        final jsonFileID = widget.child.dbSource.tabJsonFile.fileGuidToJsonFileId(testResult.fileGuid)!;
        final cardID     = await widget.child.dbSource.tabCardHead.getCardIdFromKey(jsonFileID, testResult.cardID);
        _resultCardIDMap[testResult] = cardID;

        CardData? card;
        card = _cardMap[cardID];

        if (card == null) {
          card = await CardData.create(widget.child, jsonFileID, cardID, tags: true);
          _cardMap[cardID] = card;
        }

        for (var tag in card.tagList!) {
          int? tagCount = tagMap[tag];
          if (tagCount == null) {
            tagMap[tag] = 1;
          } else {
            tagMap[tag] = tagCount + 1;
          }
        }
      }
    }

    final entries = tagMap.entries.toList();
    entries.sort((b, a) => a.value.compareTo(b.value));

    entries.insert(0, const MapEntry<String, int>('', 0));
    _tagMap.addEntries(entries);
  }

  void _refreshDisplayData() {
    _displayResultList.clear();

    if (_selTag.isEmpty) {
      _displayResultList.addAll(_resultList);
      return;
    }

    for (var result in _resultList) {
      final cardID = _resultCardIDMap[result]!;
      final card   = _cardMap[cardID]!;

      if (card.tagList!.contains(_selTag)) {
        _displayResultList.add(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(TextConst.txtStarting),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(TextConst.txtNegativeResultsReport),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Row(children: [
              ElevatedButton(
                  onPressed: () async {
                    if (await _childTestResults.pickedFromDate(context)) {
                      _refreshData();
                      _refreshDisplayData();
                      setState(() {});
                    }
                  },

                  child: Text(dateToStr(_childTestResults.fromDate))
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4),
                  child: DropdownButton<String>(
                    isExpanded: true,

                    value: _selTag,

                    items: _tagMap.keys.map<DropdownMenuItem<String>>((tag) => DropdownMenuItem(
                      value: tag,
                      child: Text('${_tagMap[tag]}: $tag'),
                    )).toList(),

                    onChanged: (value) {
                      setState(() {
                        _selTag = value!;
                        _refreshDisplayData();
                      });
                    }
                  ),
                ),
              ),

              ElevatedButton(
                  onPressed: () async {
                    if (await _childTestResults.pickedToDate(context)) {
                      _refreshData();
                      _refreshDisplayData();
                      setState(() {});
                    }
                  },

                  child: Text(dateToStr(_childTestResults.toDate))
              ),
            ]),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    return ListView(
      children: _displayResultList.map((result) => resultItem(result)).toList(),
    );
  }

  Widget resultItem(TestResult result) {
    final cardID = _resultCardIDMap[result]!;
    final card   = _cardMap[cardID]!;

    return ListTile(
      title: Text(card.body.questionData.text??card.head.title),
      subtitle: Text('${card.head.difficulty}'),
      onTap: (){
        CardView.navigatorPush(context, card);
      },
    );
  }

}
