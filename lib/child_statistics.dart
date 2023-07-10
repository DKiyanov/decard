import 'package:decard/app_state.dart';
import 'package:decard/regulator.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bar_chart.dart';
import 'child.dart';
import 'common.dart';
import 'db.dart';

typedef IntToStr = String Function(int value);

class ChildStatistics extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, Child child, SharedPreferences prefs) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => ChildStatistics(child: child, prefs: prefs)));
  }

  final Child child;
  final SharedPreferences prefs;

  const ChildStatistics({required this.child, required this.prefs, Key? key}) : super(key: key);

  @override
  State<ChildStatistics> createState() => _ChildStatisticsState();
}

class _ChildStatisticsState extends State<ChildStatistics> {
  static const int _startDayCount = 10;

  bool _isStarting = true;

  int _fromDate = 0;
  int _toDate = 0;

  late DateTime _firstDate;
  late DateTime _lastDate;

  final _resultList = <TestResult>[];
  final _chartList = <Widget>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await widget.child.updateTestResultFromServer(appState.serverConnect);

    final now = DateTime.now();
    final prev = now.add(const Duration(days: - _startDayCount));
    final next = now.add(const Duration(days: 1));
    final cur  = DateTime(next.year, next.year, next.day).add(const Duration(seconds: - 1));

    _fromDate = dateTimeToInt(DateTime(prev.year, prev.month, prev.day));
    _toDate   = dateTimeToInt(cur); // for end of current day

    final firstTime = await widget.child.dbSource.tabTestResult.getFirstTime();
    if (firstTime > 0) {
      _firstDate = intDateTimeToDateTime(firstTime);
    } else {
      _firstDate = DateTime.now();
    }

    final lastTime = await widget.child.dbSource.tabTestResult.getLastTime();
    if (lastTime > 0) {
      _lastDate = intDateTimeToDateTime(lastTime);
    } else {
      _lastDate = DateTime.now();
    }

    if (_fromDate < firstTime) _fromDate = firstTime;
    if (_toDate   > lastTime ) _toDate   = lastTime;

    await _refreshDbInfo();

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> _refreshDbInfo() async {
    _resultList.clear();
    _resultList.addAll( await widget.child.dbSource.tabTestResult.getForPeriod(_fromDate, _toDate) );
//    _testInitTestResult();
    _refreshChartList();
  }

  void _refreshChartList() {
    _chartList.clear();
    _chartList.addAll([
//      _randomBarChart(),
      _chartCountCardByGroups(),
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Row(children: [
              ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context     : context,
                      initialDate : intDateTimeToDateTime(_fromDate),
                      firstDate   : _firstDate,
                      lastDate    : _lastDate,
                    );

                    if (pickedDate == null) return;
                    _fromDate = dateTimeToInt(pickedDate);
                    await _refreshDbInfo();
                    setState(() {});
                  },

                  child: Text(dateToStr(intDateTimeToDateTime(_fromDate)))
              ),

              Expanded(child: Container()),

              ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context     : context,
                      initialDate : intDateTimeToDateTime(_toDate),
                      firstDate   : _firstDate,
                      lastDate    : _lastDate,
                    );

                    if (pickedDate == null) return;
                    _toDate = dateTimeToInt(pickedDate);
                    await _refreshDbInfo();
                    setState(() {});
                  },

                  child: Text(dateToStr(intDateTimeToDateTime(_toDate)))
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
      children: _chartList,
    );
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

    return MyBarChart(chartData: chartData);
  }

  int _getQualityRodIndex(int quality){
    if (quality <= widget.child.regulator.options.hotCardQualityTopLimit ) return 1;
    if (quality < Regulator.completelyStudiedQuality) return 2;
    return -1;
  }

  Widget _chartCountCardByGroups() {
    final collector = Collector();

    for (var testResult in _resultList) {
      final rodIndex = _getQualityRodIndex(testResult.qualityAfter);
      if (rodIndex < 0) continue;

      final group = testResult.dateTime ~/ 1000000;

      collector.addValue(group, rodIndex, 1);
    }

    return _makeChart(
        chartTitle: TextConst.txtChartCountCardByStudyGroups,

        rodDataMap: {
          1 : RodData(Colors.yellow , TextConst.txtRodCardStudyGroupActive ),
          2 : RodData(Colors.grey   , TextConst.txtRodCardStudyGroupStudied),
        },

        collector: collector,

        groupToStr: (group){
          return group.toString().substring(6);
        }
    );
  }

}
