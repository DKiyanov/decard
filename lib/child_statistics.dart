import 'package:decard/app_state.dart';
import 'package:decard/regulator.dart';
import 'package:decard/simple_menu.dart';
import 'package:flutter/material.dart';

import 'bar_chart.dart';
import 'child.dart';
import 'child_results_report.dart';
import 'common.dart';

typedef IntToStr = String Function(int value);

class QualityRange {
  final String title;
  final Color color;
  final int low;
  final int high;
  QualityRange({required this.title, required this.color, required this.low, required this.high});
}

class ChildStatistics extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, Child child) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => ChildStatistics(child: child)));
  }

  final Child child;

  const ChildStatistics({required this.child, Key? key}) : super(key: key);

  @override
  State<ChildStatistics> createState() => _ChildStatisticsState();
}

class _ChildStatisticsState extends State<ChildStatistics> {
  bool _isStarting = true;

  late ChildTestResults _childTestResults;

  final _qualityRangeList = <QualityRange>[];
  final Map<int, RodData> _qualityRangeRodMap = {};

  final _chartList = <Widget>[];

  final Map<String, GlobalKey> _chartTitleMap = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await widget.child.updateTestResultFromServer(appState.serverFunctions);
    _childTestResults = await widget.child.testResults;

    _initQualityRanges();

    _refreshChartList();

    setState(() {
      _isStarting = false;
    });
  }

  void _initQualityRanges() {
    _qualityRangeList.clear();
    _qualityRangeRodMap.clear();

    _qualityRangeList.addAll([
      QualityRange(
        title: TextConst.txtRodCardStudyGroupActive,
        color: Colors.yellow,
        low  : 0,
        high : widget.child.regulator.options.hotCardQualityTopLimit,
      ),

      QualityRange(
        title: TextConst.txtRodCardStudyGroupStudied,
        color: Colors.grey,
        low  : widget.child.regulator.options.hotCardQualityTopLimit + 1,
        high : Regulator.maxQuality,
      ),
    ]);

    for (int i = 0; i < _qualityRangeList.length; i++) {
      final qualityRange = _qualityRangeList[i];
      _qualityRangeRodMap[i] = RodData(qualityRange.color, qualityRange.title);
    }
  }

 void _refreshChartList() {
    _chartList.clear();
    _chartList.addAll([
//    _randomBarChart(),
      _chartCountCardByGroups(),
      _chartIncomingByGroups(),
      _chartOutgoingByGroups(),
    ]);
  }

  // void _testInitTestResult() {
  //   final now = DateTime.now();
  //   final Random random = Random();
  //
  //   for(var dayNum = -10; dayNum <= 0; dayNum++ ){
  //     final intDay = dateTimeToInt(now.add(Duration(days: dayNum)));
  //
  //     final testCount = random.nextInt(15);
  //
  //     for(var testNum = 1; testNum <= testCount; testNum++) {
  //       final qualityAfter = random.nextInt(100);
  //
  //       _resultList.add(TestResult(
  //           fileGuid     : 'fileGuid',
  //           fileVersion  : 1,
  //           cardID       : '1',
  //           bodyNum      : 0,
  //           result       : true,
  //           earned       : 1,
  //           dateTime     : intDay,
  //           qualityBefore: 1,
  //           qualityAfter : qualityAfter,
  //           difficulty   : 1
  //       ));
  //     }
  //   }
  // }

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
        title: Text(TextConst.txtStatistics),
        actions: [
          popupMenu(
              icon: const Icon(Icons.multiline_chart),
              menuItemList: _chartTitleMap.keys.map<SimpleMenuItem>((chartTitle) => SimpleMenuItem(
                child: Text(chartTitle),
                onPress: () async {
                  final chartKey = _chartTitleMap[chartTitle]!;
                  final chartContext = chartKey.currentContext!;
                  await Scrollable.ensureVisible(chartContext);
                }
              )).toList()
          ),

          IconButton(icon: const Icon(Icons.nearby_error ), onPressed: () async {
            await ChildResultsReport.navigatorPush(context, widget.child);
            _refreshChartList();
            setState(() {});
          }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Row(children: [
              ElevatedButton(
                  onPressed: () async {
                    if (await _childTestResults.pickedFromDate(context)) {
                      _refreshChartList();
                      setState(() {});
                    }
                  },

                  child: Text(dateToStr(_childTestResults.fromDate))
              ),

              Expanded(child: Container()),

              ElevatedButton(
                  onPressed: () async {
                    if (await _childTestResults.pickedToDate(context)) {
                      _refreshChartList();
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
    return SingleChildScrollView(
      child: Column(children: _chartList),
    );

    // return ListView(
    //   children: _chartList,
    // );
  }

  // Widget _randomBarChart() {
  //   const title = 'randomBarChart';
  //
  //   final groupDataList = <GroupData>[];
  //
  //   final Map<int, RodData> rodDataMap = {
  //     1 : RodData(Colors.green , 'green'),
  //     2 : RodData(Colors.blue  , 'blue' ),
  //   };
  //
  //   final Random random = Random();
  //
  //   for (var x = 0; x <= 11; x++) {
  //     final Map<int, double> rodValueMap = {};
  //
  //     for (var rodIndex in rodDataMap.keys) {
  //       rodValueMap[rodIndex] = random.nextInt(100).toDouble();
  //     }
  //
  //     groupDataList.add(GroupData(
  //       x            : x,
  //       xTitle       : x.toString(),
  //       rodValueMap  : rodValueMap,
  //     ));
  //   }
  //
  //   final chartData = MyBarChartData(rodDataMap, groupDataList, title);
  //
  //   return MyBarChart(chartData: chartData);
  // }

  Widget _makeChart({
    required String chartTitle,
    required Map<int, RodData> rodDataMap,
    required Collector collector,
    required IntToStr groupToStr,
  }){
    final groupDataList = <GroupData>[];

    collector.sort();

    for (var group in collector.groupList) {
      groupDataList.add(GroupData(
        x: group,
        xTitle: groupToStr(group),
      ));
    }

    for (var value in collector.valueList) {
      final groupData = groupDataList.firstWhere((groupData) => groupData.x == value.group);
      groupData.rodValueMap[value.rodIndex] = value.value;
    }

    final chartData = MyBarChartData(rodDataMap, groupDataList, chartTitle);

    final key = GlobalKey();
    _chartTitleMap[chartTitle] = key;

    return MyBarChart(chartData: chartData, key: key);
  }

  int _getQualityRodIndex(int quality){
    for (int i = 0; i < _qualityRangeList.length; i++) {
      final qualityRange = _qualityRangeList[i];
      if (quality >= qualityRange.low && quality <= qualityRange.high) return i;
    }
    return -1;
  }

  Widget _chartCountCardByGroups() {
    final collector = Collector();

    for (var testResult in _childTestResults.resultList) {
      final rodIndex = _getQualityRodIndex(testResult.qualityAfter);
      if (rodIndex < 0) continue;

      final group = testResult.dateTime ~/ 1000000;

      collector.addValue(group, rodIndex, 1);
    }

    return _makeChart(
        chartTitle: TextConst.txtChartCountCardByStudyGroups,

        rodDataMap: _qualityRangeRodMap,

        collector: collector,

        groupToStr: (group){
          return group.toString().substring(6);
        }
    );
  }

  Widget _chartIncomingByGroups() {
    final collector = Collector();

    for (var testResult in _childTestResults.resultList) {
      final rodIndexBefore = _getQualityRodIndex(testResult.qualityBefore);
      final rodIndexAfter  = _getQualityRodIndex(testResult.qualityAfter);
      if (rodIndexBefore >= rodIndexAfter) continue;

      final group = testResult.dateTime ~/ 1000000;

      collector.addValue(group, rodIndexAfter, 1);
    }

    return _makeChart(
        chartTitle: TextConst.txtChartIncomingCardByStudyGroups,

        rodDataMap: _qualityRangeRodMap,

        collector: collector,

        groupToStr: (group){
          return group.toString().substring(6);
        }
    );
  }

  Widget _chartOutgoingByGroups() {
    final collector = Collector();

    for (var testResult in _childTestResults.resultList) {
      final rodIndexBefore = _getQualityRodIndex(testResult.qualityBefore);
      final rodIndexAfter  = _getQualityRodIndex(testResult.qualityAfter);
      if (rodIndexBefore >= rodIndexAfter) continue;

      final group = testResult.dateTime ~/ 1000000;

      collector.addValue(group, rodIndexBefore, 1);
    }

    return _makeChart(
        chartTitle: TextConst.txtChartOutgoingCardByStudyGroups,

        rodDataMap: _qualityRangeRodMap,

        collector: collector,

        groupToStr: (group){
          return group.toString().substring(6);
        }
    );
  }

}
