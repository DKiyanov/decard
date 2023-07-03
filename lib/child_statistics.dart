import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';
import 'package:collection/collection.dart';

import 'child.dart';
import 'common.dart';

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
  bool _isStarting = true;

  final points = getPricePoints();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await getDbInfo();

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> getDbInfo() async {

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
    return points.map((point) =>
        BarChartGroupData(
            x: point.x.toInt(),
            barRods: [
              BarChartRodData(
                  toY: point.y
              )
            ]
        )

    ).toList();
  }

  SideTitles _getBottomTitles() {
    return SideTitles(
      showTitles: true,
      getTitlesWidget: (value, meta) {
        String text = '';
        switch (value.toInt()) {
          case 0:
            text = 'Jan';
            break;
          case 2:
            text = 'Mar';
            break;
          case 4:
            text = 'May';
            break;
          case 6:
            text = 'Jul';
            break;
          case 8:
            text = 'Sep';
            break;
          case 10:
            text = 'Nov';
            break;
        }

        return Text(text);
      },
    );
  }

}

class PricePoint {
  final double x;
  final double y;

  PricePoint({required this.x, required this.y});
}

List<PricePoint> getPricePoints() {
  final Random random = Random();
  final randomNumbers = <double>[];

  for (var i = 0; i <= 11; i++) {
    randomNumbers.add(random.nextDouble());
  }

  return randomNumbers.mapIndexed((index, element) => PricePoint(x: index.toDouble(), y: element)).toList();
}