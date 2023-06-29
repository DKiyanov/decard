import 'package:decard/regulator.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'common_widgets.dart';

class DifficultyEditor extends StatefulWidget {
  static Future<RegDifficulty?> navigatorPush(BuildContext context, RegDifficulty? difficulty, List<int> busyLevelList) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => DifficultyEditor(difficulty: difficulty, busyLevelList: busyLevelList)));
  }

  final RegDifficulty? difficulty;
  final List<int> busyLevelList;
  const DifficultyEditor({required this.difficulty, required this.busyLevelList, Key? key}) : super(key: key);

  @override
  State<DifficultyEditor> createState() => _DifficultyEditorState();
}

class _DifficultyEditorState extends State<DifficultyEditor> {

  int level = 0;

  // integer, the number of seconds earned if the answer is correct
  final maxCost = TextEditingController();
  final minCost = TextEditingController();

  // integer, the number of penalty seconds in case of NOT correct answer
  final maxPenalty = TextEditingController();
  final minPenalty = TextEditingController();

  // integer, the number of attempts at a solution in one approach
  final maxTryCount = TextEditingController();
  final minTryCount = TextEditingController();

  // integer, seconds, the time allotted for the solution
  final maxDuration = TextEditingController();
  final minDuration = TextEditingController();

  // integer, the lower value of the cost as a percentage of the current set cost
  final maxDurationLowCostPercent = TextEditingController();
  final minDurationLowCostPercent = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.difficulty == null) return;

    level = widget.difficulty!.level;

    minCost.text = widget.difficulty!.minCost.toString();
    maxCost.text = widget.difficulty!.maxCost.toString();
    minPenalty.text = widget.difficulty!.minPenalty.toString();
    maxPenalty.text = widget.difficulty!.maxPenalty.toString();
    minTryCount.text = widget.difficulty!.minTryCount.toString();
    maxTryCount.text = widget.difficulty!.maxTryCount.toString();
    minDuration.text = widget.difficulty!.minDuration.toString();
    maxDuration.text = widget.difficulty!.maxDuration.toString();
    minDurationLowCostPercent.text = widget.difficulty!.minDurationLowCostPercent.toString();
    maxDurationLowCostPercent.text = widget.difficulty!.maxDurationLowCostPercent.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
            Navigator.pop(context);
          }),
          centerTitle: true,
          title: Text(TextConst.txtRegDifficultyTuning),
          actions: [
            IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: ()=> _saveAndExit() )
          ],
        ),

        body: SafeArea(
          child: _body(),
        )
    );
  }

  Widget _body() {
    return Column(children: [
      _levelSelector(),
      _editParam(TextConst.drfDifficultyCost    , minCost,     maxCost),
      _editParam(TextConst.drfDifficultyPenalty , minPenalty,  maxPenalty),
      _editParam(TextConst.drfDifficultyTryCount, minTryCount, maxTryCount),
      _editParam(TextConst.drfDifficultyDuration, minDuration, maxDuration),
      _editParam(TextConst.drfDifficultyDurationLowCostPercent, minDurationLowCostPercent, maxDurationLowCostPercent),
    ]);
  }

  Widget _editParam(String title, TextEditingController tecValueMin, TextEditingController tecValueMax) {
    return Column(
      children: [
        Text(title),
        Row( children: [
          intFiled(tecValueMin),
          intFiled(tecValueMax),
        ]),
      ],
    );
  }

  Widget _levelSelector(){
    final items = <DropdownMenuItem<int>>[];

    for (int level = Regulator.lowDifficultyLevel + 1; level < Regulator.highDifficultyLevel; level++) {
      Color? color;

      if (widget.difficulty!.level == level) {
        color = Colors.green;
      } else {
        if (widget.busyLevelList.contains(level)) {
          color = Colors.grey;
        }
      }

      items.add(DropdownMenuItem<int>(
        value: level,
        child: Container(color: color, child: Text(level.toString())),
      ));
    }

    return Row(
      children: [
        Text(TextConst.drfDifficultyLevel),
        DropdownButton<int>(
          value: level,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: (int? value) {
            setState(() {
              level = value!;
            });
          },
          items: items,
        ),
      ],
    );
  }

  void _saveAndExit() {
    final intMaxCost                   = int.tryParse(maxCost.text)??0;
    final intMinCost                   = int.tryParse(minCost.text)??0;
    final intMaxPenalty                = int.tryParse(maxPenalty.text)??0;
    final intMinPenalty                = int.tryParse(minPenalty.text)??0;
    final intMaxTryCount               = int.tryParse(maxTryCount.text)??0;
    final intMinTryCount               = int.tryParse(minTryCount.text)??0;
    final intMaxDuration               = int.tryParse(maxDuration.text)??0;
    final intMinDuration               = int.tryParse(minDuration.text)??0;
    final intMaxDurationLowCostPercent = int.tryParse(maxDurationLowCostPercent.text)??0;
    final intMinDurationLowCostPercent = int.tryParse(minDurationLowCostPercent.text)??0;

    final newDifficulty =  RegDifficulty(
      level                     : level,
      maxCost                   : intMaxCost,
      minCost                   : intMinCost,
      maxPenalty                : intMaxPenalty,
      minPenalty                : intMinPenalty,
      maxTryCount               : intMaxTryCount,
      minTryCount               : intMinTryCount,
      maxDuration               : intMaxDuration,
      minDuration               : intMinDuration,
      maxDurationLowCostPercent : intMaxDurationLowCostPercent,
      minDurationLowCostPercent : intMinDurationLowCostPercent,
    );

    Navigator.pop(context, newDifficulty);
  }
}
