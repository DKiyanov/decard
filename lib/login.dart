import 'package:decard/server_connect.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'common.dart';

class Login extends StatefulWidget {
  final ServerConnect serverConnect;
  final bool editConnection;
  final VoidCallback onLoginOk;

  const Login({required this.serverConnect, required this.editConnection, required this.onLoginOk, Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _tcServerURL = TextEditingController();
  final TextEditingController _tcLogin     = TextEditingController();
  final TextEditingController _tcPassword  = TextEditingController();

  bool _urlReadOnly = false;
  bool _loginReadOnly = false;
  String _displayError = '';

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _tcServerURL.text = widget.serverConnect.serverURL;
    _tcLogin.text     = widget.serverConnect.login;


    if (_tcServerURL.text.isEmpty){
      _tcServerURL.text = TextConst.defaultURL;
    }

    if (_tcLogin.text.isEmpty){
      _tcLogin.text     = TextConst.defaultLogin;
    }

    if (_tcServerURL.text.isNotEmpty && !widget.editConnection){
      _urlReadOnly = true;
    }
    if (_tcLogin.text.isNotEmpty  && !widget.editConnection){
      _loginReadOnly = true;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(

        appBar: AppBar(
          centerTitle: true,
          title: Text(TextConst.txtEntryToOptions),
        ),

        body: Padding(padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8), child:
        Column(children: [

          // Server address
          TextFormField(
            controller: _tcServerURL,
            readOnly: _urlReadOnly,
            decoration: InputDecoration(
              filled: true,
              labelText: TextConst.txtServerURL,
            ),
          ),

          // User login
          TextFormField(
            controller: _tcLogin,
            readOnly: _loginReadOnly,
            decoration: InputDecoration(
              filled: true,
              labelText: TextConst.txtLogin,
            ),
          ),

          // Password
          TextFormField(
            controller: _tcPassword,
            decoration: InputDecoration(
              filled: true,
              labelText: TextConst.txtPassword,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(_obscurePassword?Icons.abc:Icons.password),
              ),
            ),
            obscureText: _obscurePassword,
          ),

          if (!widget.editConnection) ...[
            ElevatedButton(child: Text(TextConst.txtSignIn), onPressed: ()=> checkAndGo(false)),
          ],

          if (widget.editConnection || (!widget.serverConnect.loggedIn)) ...[
            ElevatedButton(child: Text(TextConst.txtSignUp), onPressed: ()=> checkAndGo(true)),
          ],

          if (_displayError.isNotEmpty) ...[
            Text(_displayError),
          ],
        ])
        )
    );
  }

  Future<void> checkAndGo(bool signUp) async {
    String url      = _tcServerURL.text.trim();
    String login    = _tcLogin.text.trim();
    String password = _tcPassword.text.trim();

    if (url.isEmpty || login.isEmpty || password.isEmpty){
      Fluttertoast.showToast(msg: TextConst.txtInputAllParams);
      return;
    }

    final ret = await widget.serverConnect.setConnectionParam(url, login, password, signUp);
    if (!ret) {
      setState(() {
        _displayError = widget.serverConnect.lastError;
      });
      return;
    }

    widget.onLoginOk();
  }

}