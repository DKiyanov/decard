import 'package:decard/app_state.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';
import 'package:collection/collection.dart';

import 'bar_chart.dart';
import 'child.dart';
import 'common.dart';
import 'db.dart';

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
    _initParam();
//    await widget.child.updateTestResultFromServer(appState.serverConnect);
    await _refreshDbInfo();

    setState(() {
      _isStarting = false;
    });
  }

  void _initParam() {
    final now = DateTime.now();
    final prev = now.add(const Duration(days: - _startDayCount));
    final next = now.add(const Duration(days: 1));
    final cur  = DateTime(next.year, next.year, next.day).add(const Duration(seconds: - 1));

    _fromDate = dateTimeToInt(DateTime(prev.year, prev.month, prev.day));
    _toDate   = dateTimeToInt(cur); // for end of current day
  }

  Future<void> _refreshDbInfo() async {
    _resultList.clear();
//    _resultList.addAll( await widget.child.dbSource.tabTestResult.getForPeriod(_fromDate, _toDate) );
    _refreshChartList();
  }

  void _refreshChartList() {
    _chartList.clear();
    _chartList.addAll([
      _randomBarChart(),
      _randomBarChart(),
    ]);
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
        title: Text(TextConst.txtStatistics),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    return ListView(
      children: _chartList,
    );
  }

  Widget _randomBarChart() {
    const title = 'randomBarChart';

    final groupDataList = <GroupData>[];

    final rodDataList = <RodData>[
      RodData(Colors.green, 'green'),
      RodData(Colors.blue, 'blue'),
    ];

    final Random random = Random();

    for (var x = 0; x <= 11; x++) {
      final rodValueList = <int>[];

      for (var r = 0; r < rodDataList.length; r++) {
        rodValueList.add(random.nextInt(100));
      }

      groupDataList.add(GroupData(
        x            : x,
        xTitle       : x.toString(),
        rodValueList : rodValueList,
      ));
    }

    final chartData = MyBarChartData(rodDataList, groupDataList, title);

    return MyBarChart(chartData: chartData);
  }

  Widget _chartCountCardByGroups() {
    // Кол-во: новых, активных, изученых - соотв.  текуще кол-во на конец дня

    final title = TextConst.txtChartCountCardByStudyGroups;

    final groupDataList = <GroupData>[];

    final rodDataList = <RodData>[
      RodData(Colors.red    , TextConst.txtRodCardStudyGroupNew),
      RodData(Colors.yellow , TextConst.txtRodCardStudyGroupActive),
      RodData(Colors.grey   , TextConst.txtRodCardStudyGroupStudied),
    ];


    for (var testResult in _resultList) {

    }


    final chartData = MyBarChartData(rodDataList, groupDataList, title);

    return MyBarChart(chartData: chartData);
  }
}
