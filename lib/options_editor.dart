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

    hotDayCount.text                       = _regulator.options.hotDayCount.toString();
    hotCardQualityTopLimit.text            = _regulator.options.hotCardQualityTopLimit.toString();
    maxCountHotCard.text                   = _regulator.options.maxCountHotCard.toString();
    hotGroupMinQualityTopLimit.text        = _regulator.options.hotGroupMinQualityTopLimit.toString();
    hotGroupAvgQualityTopLimit.text        = _regulator.options.hotGroupAvgQualityTopLimit.toString();
    minCountHotQualityGroup.text           = _regulator.options.minCountHotQualityGroup.toString();
    lowGroupAvgQualityTopLimit.text        = _regulator.options.lowGroupAvgQualityTopLimit.toString();
    maxCountLowQualityGroup.text           = _regulator.options.maxCountLowQualityGroup.toString();
    lowTryCount.text                       = _regulator.options.lowTryCount.toString();
    lowDayCount.text                       = _regulator.options.lowDayCount.toString();
    negativeLastResultMaxQualityLimit.text = _regulator.options.negativeLastResultMaxQualityLimit.toString();
    minEarnTransferMinutes.text            = _regulator.options.minEarnTransferMinutes.toString();

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
      _editParam(TextConst.drfOptionHotDayCount                      , hotDayCount),
      _editParam(TextConst.drfOptionHotCardQualityTopLimit           , hotCardQualityTopLimit),
      _editParam(TextConst.drfOptionMaxCountHotCard                  , maxCountHotCard),
      _editParam(TextConst.drfOptionHotGroupMinQualityTopLimit       , hotGroupMinQualityTopLimit,        TextConst.drfOptionHotGroupDetermine),
      _editParam(TextConst.drfOptionHotGroupAvgQualityTopLimit       , hotGroupAvgQualityTopLimit,        TextConst.drfOptionHotGroupDetermine),
      _editParam(TextConst.drfOptionMinCountHotQualityGroup          , minCountHotQualityGroup,           TextConst.drfOptionMinCountHotQualityGroupHelp),
      _editParam(TextConst.drfOptionLowGroupAvgQualityTopLimit       , lowGroupAvgQualityTopLimit),
      _editParam(TextConst.drfOptionMaxCountLowQualityGroup          , maxCountLowQualityGroup,           TextConst.drfOptionMaxCountLowQualityGroupHelp),
      _editParam(TextConst.drfOptionLowTryCount                      , lowTryCount,                       TextConst.drfOptionLowHelp),
      _editParam(TextConst.drfOptionLowDayCount                      , lowDayCount,                       TextConst.drfOptionLowHelp),
      _editParam(TextConst.drfOptionNegativeLastResultMaxQualityLimit, negativeLastResultMaxQualityLimit, TextConst.drfOptionNegativeLastResultMaxQualityLimitHelp),
      _editParam(TextConst.drfOptionMinEarnTransferMinutes           , minEarnTransferMinutes),
    ]);

    return result;
  }

  Widget _editParam(String title, TextEditingController tecValue, [String? paramHelp]) {
    Widget paramTitle;
    if (paramHelp == null) {
      paramTitle = Text(title);
    } else {
      paramTitle = GestureDetector(
        child: Container(color: Colors.yellowAccent, child: Text(title)),
        onTap: () {
          _showParamHelp(paramHelp);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row( children: [
        Expanded(flex: 3,
            child: paramTitle
        ),
        Expanded(child: intFiled(tecValue)),
      ]),
    );
  }

  void _showParamHelp(String paramHelp){
    showDialog(context: context, builder: (BuildContext context){
      return AlertDialog(
        content: Text(paramHelp),
        backgroundColor: Colors.yellowAccent,
      );
    });
  }

  Future<void> _saveAndExit() async {

    final options = RegOptions(
        hotDayCount                       : int.tryParse(hotDayCount.text)??0,
        hotCardQualityTopLimit            : int.tryParse(hotCardQualityTopLimit.text)??0,
        maxCountHotCard                   : int.tryParse(maxCountHotCard.text)??0,
        hotGroupMinQualityTopLimit        : int.tryParse(hotGroupMinQualityTopLimit.text)??0,
        hotGroupAvgQualityTopLimit        : int.tryParse(hotGroupAvgQualityTopLimit.text)??0,
        minCountHotQualityGroup           : int.tryParse(minCountHotQualityGroup.text)??0,
        lowGroupAvgQualityTopLimit        : int.tryParse(lowGroupAvgQualityTopLimit.text)??0,
        maxCountLowQualityGroup           : int.tryParse(maxCountLowQualityGroup.text)??0,
        lowTryCount                       : int.tryParse(lowTryCount.text)??0,
        lowDayCount                       : int.tryParse(lowDayCount.text)??0,
        minEarnTransferMinutes            : int.tryParse(minEarnTransferMinutes.text)??0,
        negativeLastResultMaxQualityLimit : int.tryParse(negativeLastResultMaxQualityLimit.text)??0,
    );

    final changed =
        _regulator.options.hotDayCount                       != options.hotDayCount                       ||
        _regulator.options.hotCardQualityTopLimit            != options.hotCardQualityTopLimit            ||
        _regulator.options.maxCountHotCard                   != options.maxCountHotCard                   ||
        _regulator.options.hotGroupMinQualityTopLimit        != options.hotGroupMinQualityTopLimit        ||
        _regulator.options.hotGroupAvgQualityTopLimit        != options.hotGroupAvgQualityTopLimit        ||
        _regulator.options.minCountHotQualityGroup           != options.minCountHotQualityGroup           ||
        _regulator.options.lowGroupAvgQualityTopLimit        != options.lowGroupAvgQualityTopLimit        ||
        _regulator.options.maxCountLowQualityGroup           != options.maxCountLowQualityGroup           ||
        _regulator.options.lowTryCount                       != options.lowTryCount                       ||
        _regulator.options.lowDayCount                       != options.lowDayCount                       ||
        _regulator.options.minEarnTransferMinutes            != options.minEarnTransferMinutes            ||
        _regulator.options.negativeLastResultMaxQualityLimit != options.negativeLastResultMaxQualityLimit;

    if (changed) {
      final newRegulator = Regulator(
        options        : options,
        cardSetList    : _regulator.cardSetList,
        difficultyList : _regulator.difficultyList,
      );
      await newRegulator.saveToFile(widget.child.regulatorPath);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
