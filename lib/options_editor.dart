import 'package:decard/regulator.dart';
import 'package:flutter/material.dart';

import 'child.dart';
import 'common.dart';
import 'common_widgets.dart';

class OptionsEditor extends StatefulWidget {
  static Future<bool?> navigatorPush(BuildContext context, Child child) async {
    return Navigator.push<bool>(context, MaterialPageRoute( builder: (_) => OptionsEditor(child: child)));
  }

  final Child child;

  const OptionsEditor({required this.child, Key? key}) : super(key: key);

  @override
  State<OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<OptionsEditor> {
  bool _isStarting = true;
  late Regulator _regulator;

  bool _changed = false;

  final hotDayCount = TextEditingController();   // Number of days for which the statistics are calculated

  final hotCardQualityTopLimit = TextEditingController(); // cards with lower quality are considered to be actively studied
  final maxCountHotCard = TextEditingController();        // Maximum number of cards in active study

  /// limits to determine the activity of the group
  final hotGroupMinQualityTopLimit = TextEditingController(); // Minimum quality for the cards included in the group
  final hotGroupAvgQualityTopLimit = TextEditingController(); // Average quality of the cards included in the group

  /// the minimum number of active study groups,
  /// If the quantity is less than the limit - the system tries to select a card from the new group
  final minCountHotQualityGroup = TextEditingController();

  final lowGroupAvgQualityTopLimit = TextEditingController(); // the upper limit of average quality for begin-quality groups

  /// maximal number of begin-quality groups,
  /// If the number is equal to the limit - the system selects cards from the groups already being studied
  final maxCountLowQualityGroup = TextEditingController();

  /// Decrease the quality when the amount of statistics is small
  ///   if the new card has very good results from the beginning
  ///   these parameters will not let the quality grow too fast
  final lowTryCount = TextEditingController(); // minimum number of tests
  final lowDayCount = TextEditingController(); // minimum number of days

  /// Maximum available quality with a negative last result
  final negativeLastResultMaxQualityLimit = TextEditingController();

  final minEarnTransferMinutes = TextEditingController();

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
        title: Text(TextConst.txtRegOptionsTuning),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: ()=> _saveAndExit() )
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(10.0),
          children: _body(),
        ),
      ),
    );
  }

  List<Widget> _body() {
    final result = <Widget>[];

    result.addAll([
      _editParam(TextConst.drfOptionHotDayCount, hotDayCount),
    ]);

    return result;
  }

  Widget _editParam(String title, TextEditingController tecValue) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row( children: [
        Expanded(child: Text(title)),
        Expanded(child: intFiled(tecValue)),
      ]),
    );
  }

  Future<void> _saveAndExit() async {
    if (_changed) {
      await _regulator.saveToFile(widget.child.regulatorPath);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
