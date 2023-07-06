import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GroupData {
  final int x;
  final String xTitle;
  final List<int> rodValueList;

  GroupData({required this.x, required this.xTitle, required this.rodValueList});
}

class RodData {
  final Color color;
  final String title;

  RodData(this.color, this.title);
}

class MyBarChartData {
  final List<RodData> rodDataList;
  final List<GroupData> groupDataList;
  final String title;

  MyBarChartData(this.rodDataList, this.groupDataList, this.title);
}

class MyBarChart extends StatelessWidget {
  final MyBarChartData chartData;
  const MyBarChart({required this.chartData, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final barChart = BarChart(
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
    );

    return  Column(
      children: [
        Text(chartData.title),

        AspectRatio(
          aspectRatio: 2,
          child: barChart,
        ),

        Wrap(children: chartData.rodDataList.map((rod) =>
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10),
              Text(rod.title),
              Container(width: 4),
              Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: rod.color,
                  borderRadius: const BorderRadius.all(Radius.circular(5))
                ),
              )
            ])).toList()
        ),


      ],
    );
  }

  List<BarChartGroupData> _chartGroups() {
    final resultList = <BarChartGroupData>[];

    for (var groupData in chartData.groupDataList) {
      final rodList = <BarChartRodData>[];

      for (var rodIndex = 0; rodIndex < groupData.rodValueList.length; rodIndex++) {
        rodList.add( BarChartRodData(
          toY: groupData.rodValueList[rodIndex].toDouble(),
          color: chartData.rodDataList[rodIndex].color,
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
        final groupData = chartData.groupDataList.firstWhere((groupData) => groupData.x == value);
        return Text(groupData.xTitle);
      },
    );
  }

}
