import 'package:decard/regulator.dart';
import 'package:flutter/material.dart';

import 'child.dart';
import 'common.dart';
import 'common_widgets.dart';
import 'difficulty_editor.dart';

class DifficultyList extends StatefulWidget {
  static Future<bool?> navigatorPush(BuildContext context, Child child) async {
    return Navigator.push<bool>(context, MaterialPageRoute( builder: (_) => DifficultyList(child: child)));
  }

  final Child child;

  const DifficultyList({required this.child, Key? key}) : super(key: key);

  @override
  State<DifficultyList> createState() => _DifficultyListState();
}

class _DifficultyListState extends State<DifficultyList> {
  bool _isStarting = true;
  late Regulator _regulator;

  bool _changed = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    _regulator = await Regulator.fromFile( widget.child.regulatorPath );
    _regulator.fillDifficultyLevels(true);

    setState(() {
      _isStarting = false;
    });
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
          leading: IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
            Navigator.pop(context, false);
          }),
          centerTitle: true,
          title: Text(TextConst.txtRegDifficultyLevelsTuning),
          actions: [
            IconButton(icon: const Icon(Icons.help_outline), onPressed: ()=> showHelp(context, TextConst.txtDifficultyHelp) ),
            IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: ()=> _saveAndExit() )
          ],
        ),

        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(10.0),
            children: _body(),
          ),
        ),

        floatingActionButton: FloatingActionButton(
          child: const Icon( Icons.add),
          onPressed: () {
            _editDifficulty();
          },
        ),
    );
  }

  List<Widget> _body() {
    final result = <Widget>[];

    result.add(ListTile(
      title: DefaultTextStyle(
        style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Text(TextConst.txtDifficultyColumn1 )
          ),

          Expanded(
              child: Align(alignment: Alignment.centerRight, child: Text(TextConst.txtDifficultyColumn2)),
          ),

          Expanded(
            child: Align(alignment: Alignment.centerRight, child: Text(TextConst.txtDifficultyColumn3)),
          ),
        ]),
      ),
    ));

    for (var item in _regulator.difficultyList) {
      result.add(_getItemWidget(item));
    }

    return result;
  }

  Widget _getItemWidget(RegDifficulty item) {
    return ListTile(
      title: Column(children: [
        Row(
          children: [
            Expanded(child: Text(TextConst.drfDifficultyLevel, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold) )),
            Expanded(child: Text(item.level.toString(), textAlign: TextAlign.right, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
          ],
        ),

        _viewParam(TextConst.drfDifficultyCost    , item.maxCost,     item.minCost),
        _viewParam(TextConst.drfDifficultyPenalty , item.minPenalty,  item.maxPenalty),
        _viewParam(TextConst.drfDifficultyTryCount, item.maxTryCount, item.minTryCount),
        _viewParam(TextConst.drfDifficultyDuration, item.maxDuration, item.minDuration),
        _viewParam(TextConst.drfDifficultyDurationLowCostPercent, item.maxDurationLowCostPercent, item.minDurationLowCostPercent),
      ]),

      onLongPress: () {
        _editDifficulty(item);
      },
    );
  }

  Widget _viewParam(String title, int valueMin, int valueMax) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.grey,
                  width: 1
              )
          )
      ),

      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 6),
        child: Row( crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(flex: 2, child: Text(title, style: const TextStyle(fontSize: 13) )),
          Expanded(child: Text(valueMin.toString(), textAlign: TextAlign.right , style: const TextStyle(fontSize: 13))),
          Expanded(child: Text(valueMax.toString(), textAlign: TextAlign.right , style: const TextStyle(fontSize: 13))),
        ]),
      ),
    );
  }

  Future<void> _editDifficulty([RegDifficulty? item]) async {
    final busyLevelList = _regulator.difficultyList.map((difficulty) => difficulty.level).toList();
    final newDifficulty = await DifficultyEditor.navigatorPush(context, item, busyLevelList);
    if (newDifficulty == null) return;

    setState(() {
      if (item != null) {
        _regulator.difficultyList.remove(item);
      }

      _regulator.difficultyList.removeWhere((difficulty) => difficulty.level == newDifficulty.level);

      _regulator.difficultyList.add(newDifficulty);

      _regulator.difficultyList.sort((a, b) => a.level.compareTo(b.level));

      _changed = true;
    });
  }

  Future<void> _saveAndExit() async {
    if (_changed) {
      await _regulator.saveToFile(widget.child.regulatorPath);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

}


