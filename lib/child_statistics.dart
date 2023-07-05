import 'package:decard/app_state.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';
import 'package:collection/collection.dart';

import 'child.dart';
import 'common.dart';
import 'db.dart';

class GroupData {
  final int x;
  final String xTitle;
  final List<int> rodValueList;

  GroupData({required this.x, required this.xTitle, required this.rodValueList});
}

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

  final _rodColorList  = <Color>[];
  final _groupDataList = <GroupData>[];

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
//    await refreshDbInfo();
    _initRandomData();

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

  Future<void> refreshDbInfo() async {
    _resultList.clear();
    _resultList.addAll( await widget.child.dbSource.tabTestResult.getForPeriod(_fromDate, _toDate) );
  }

  // void collectG1() {
  //   // Кол-во: новых, активных, изученых - соотв.  текуще кол-во на конец дня
  //
  //   for (var test in _resultList) {
  //
  //   }
  // }

  void _initRandomData() {
    _rodColorList.clear();
    _groupDataList.clear();

    _rodColorList.addAll([Colors.green, Colors.blue]);

    _groupDataList.addAll(_getRandomGroupData());
  }

  List<GroupData> _getRandomGroupData() {
    final Random random = Random();

    final resultList = <GroupData>[];

    for (var x = 0; x <= 11; x++) {
      final rodValueList = <int>[];

      for (var r = 0; r < _rodColorList.length; r++) {
        rodValueList.add(random.nextInt(100));
      }

      resultList.add(GroupData(
        x            : x,
        xTitle       : x.toString(),
        rodValueList : rodValueList,
      ));
    }

    return resultList;
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
    return AspectRatio(
      aspectRatio: 2,
      child: BarChart(
        BarChartData(
          barGroups: _chartGroups(),
          borderData: FlBorderData(
            border: const Border(bottom: BorderSide(), left: BorderSide())
          ),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles : AxisTitles(sideTitles: _getBottomTitles()),
            leftTitles   : AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles    : AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles  : AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _chartGroups() {
    final resultList = <BarChartGroupData>[];

    for (var groupData in _groupDataList) {
      final rodList = <BarChartRodData>[];

      for (var rodIndex = 0; rodIndex < groupData.rodValueList.length; rodIndex++) {
        rodList.add( BarChartRodData(
          toY: groupData.rodValueList[rodIndex].toDouble(),
          color: _rodColorList[rodIndex],
        ));
      }

      resultList.add( BarChartGroupData(
        x: groupData.x,
        barRods: rodList
      ));
    }

    return resultList;
  }

  SideTitles _getBottomTitles() {
    return SideTitles(
      showTitles: true,
      getTitlesWidget: (value, meta) {
        final groupData = _groupDataList.firstWhere((groupData) => groupData.x == value);
        return Text(groupData.xTitle);
      },
    );
  }
}
