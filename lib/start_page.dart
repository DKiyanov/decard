import 'package:decard/parse_connect.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'card_testing.dart';
import 'common.dart';
import 'login_invite.dart';
import 'options.dart';

class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  static const String _keyNotFirstRun = 'NotFirstRun';
  static const String _keyFirstConfigOk = 'FirstConfigOk';

  bool _isStarting = true;
  SharedPreferences? _prefs;
  final LoginMode _loginMode = LoginMode.child;
  bool _firstRun = false;
  bool _reLogin = false;
  int _appStateInitMode = 0;
  bool _showFirstConfig = false;

  ParseConnect? _serverConnect;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    _prefs = await SharedPreferences.getInstance();
    _serverConnect = ParseConnect(_prefs!);

    _firstRun = !(_prefs!.getBool(_keyNotFirstRun)??false);

    if (!_firstRun) {
      await _serverConnect!.wakeUp();

      _showFirstConfig = !(_prefs!.getBool(_keyFirstConfigOk)??false);
    }

    setState(() {
      _isStarting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting) {
      return _wait();
    }

    if (_firstRun) {
      return _login(
        onLoginOk: (){
          _prefs!.setBool(_keyNotFirstRun, true);

          setState(() {
            _firstRun = false;

            if (_loginMode == LoginMode.child) {
              _showFirstConfig = true;
            }
          });
        },

        onLoginCancel: () {
          setState(() {
            _firstRun = true;
          });
        }
      );
    }

    if (_reLogin) {
      return _login(
          onLoginOk: (){
            setState(() {
              _reLogin = false;
            });
          }
      );
    }

    if (_appStateInitMode == 0) {
      _appStateInitMode = 1;
        appState.initialization(_serverConnect!, _loginMode).then((_) {
        setState(() {
          _appStateInitMode = 2;
        });
      });
    }
    if (_appStateInitMode < 2) {
      return _wait();
    }

    if (_showFirstConfig) {
      return Options( onOptionsOk: (){
        _prefs!.setBool(_keyFirstConfigOk, true);
        setState(() {
          _showFirstConfig = false;
        });
      });
    }

    if (_loginMode == LoginMode.child) {
      return DeCard(child: appState.childList.first);
    }

    return Container();
  }

  Widget _login({required VoidCallback onLoginOk, VoidCallback? onLoginCancel}) {
    return LoginInvite(connect: _serverConnect!, loginMode: _loginMode, title: TextConst.txtConnecting, onLoginOk: onLoginOk, onLoginCancel: onLoginCancel);
  }

  Widget _wait() {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(TextConst.txtStarting),
      ),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${TextConst.version}: ${TextConst.versionDateStr}'),
        Container(height: 10),
        const CircularProgressIndicator(),
      ])),
    );
  }

}