import 'package:decard/select_usage_mode.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'card_testing.dart';
import 'common.dart';
import 'login.dart';

class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _isStarting = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await appState.init();

    setState(() {
      _isStarting = false;
    });
  }

  Widget getScreenWidget() {
    if (appState.firstRun) {
      if (!appState.serverConnect.loggedIn) {
        return Login(
          serverConnect: appState.serverConnect,
          editConnection: true,
          onLoginOk: (){
            setState(() {});
          },
        );
      } else {
        return UsingModeSelector(onUsingModeSelectOk: () {
          setState(() {});
        });
      }
    }

    if (appState.usingMode == UsingMode.testing) {
      return DeCard(child: appState.childList.first);
    }

    if (appState.usingMode == UsingMode.manager) {
      // TODO return child list
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

    return getScreenWidget();
  }

}