import 'package:decard/select_usage_mode.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'card_testing.dart';
import 'common.dart';
import 'db_file_list.dart';

class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _isStarting = true;
  Widget? _screen;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await appState.init();

    _screen = getScreenWidget();

    setState(() {
      _isStarting = false;
    });
  }

  Widget getScreenWidget() {
    if (appState.firstRun) {
      return const UsingModeSelector();
    }
    if (appState.usingMode == UsingMode.testing) {
      return const DeCard();
    }
    if (appState.usingMode == UsingMode.editCard) {
      return const DbFileList();
    }
    return Container();
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

    return _screen!;
  }

}