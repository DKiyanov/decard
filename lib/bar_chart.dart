import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ValueForCollect {
  final int group;
  final int rodIndex;
  final double value;

  ValueForCollect(this.group, this.rodIndex, this.value);
}

class CollectValue {
  final int group;
  final int rodIndex;
  double value;
  int count;
  CollectValue(this.group, this.rodIndex, this.value, [this.count = 1]);
}

class Collector {
  final groupList = <int>[];
  final rodList   = <int>[];
  final valueList = <CollectValue>[];

  void addValue(int group, int rodIndex, double value) {
    final item = valueList.firstWhereOrNull( (item) => item.group == group && item.rodIndex == rodIndex );
    if (item != null) {
      item.value += value;
      item.count += 1;
    } else {
      valueList.add(CollectValue(group, rodIndex, value));

      if (!groupList.any((element) => element == group)) {
        groupList.add(group);
      }

      if (!rodList.any((element) => element == rodIndex)) {
        rodList.add(rodIndex);
      }
    }
  }

  void sort() {
    groupList.sort((a, b) => a.compareTo(b));
    rodList.sort((a, b) => a.compareTo(b));

    valueList.sort((a, b) {
      final cmp = a.group.compareTo(b.group);
      if (cmp != 0) return cmp;
      return a.rodIndex.compareTo(b.rodIndex);
    });
  }
}

class GroupData {
  final int x;
  final String xTitle;
  final Map<int, double> rodValueMap = {}; // rod index, value

  GroupData({required this.x, required this.xTitle, Map<int, double>? rodValueMap }){
    if (rodValueMap != null) this.rodValueMap.addAll(rodValueMap);
  }
}

class RodData {
  final Color color;
  final String title;

  RodData(this.color, this.title);
}

class MyBarChartData {
  final Map<int, RodData> rodDataMap; // rod index, RodData
  final List<GroupData> groupDataList;
  final String title;
  late  List<int> rodIndexList;

  MyBarChartData(this.rodDataMap, this.groupDataList, this.title){
    rodIndexList = List.from(rodDataMap.keys);
    rodIndexList.sort((a,b) => a.compareTo(b));
  }
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

        Wrap(children: chartData.rodDataMap.values.map((rod) =>
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

      for (var rodIndex in chartData.rodIndexList) {
        rodList.add( BarChartRodData(
          toY: groupData.rodValueMap[rodIndex]??0.0,
          color: chartData.rodDataMap[rodIndex]!.color,
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
