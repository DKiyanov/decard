import 'package:decard/app_state.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'common.dart';
import 'options_editor.dart';

class PasswordInput extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context) async {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordInput() ));
  }
  static Future<Object?> navigatorPushReplacement(BuildContext context) async {
    return Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PasswordInput() ));
  }

  const PasswordInput({Key? key}) : super(key: key);

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  final passwordController = TextEditingController();
  bool obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
            Navigator.pop(context);
          }),
          centerTitle: true,
          title: Text(TextConst.txtPasswordEntry),
        ),

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: [

                TextField(
                  controller: passwordController,
                  obscureText: obscureText,
                  enableSuggestions: false,
                  autocorrect: false,

                  decoration: InputDecoration(
                    labelText: TextConst.txtInputPassword,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.blue),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    suffixIcon : IconButton(
                      icon: Icon(obscureText? Icons.abc : Icons.password),
                      onPressed: ()=> {
                        setState((){
                          obscureText = !obscureText;
                        })
                      },
                    ),
                  ),
                ),

                Container(height: 8),

                ElevatedButton(onPressed: proceed, child: Text(TextConst.txtProceed)),
              ],
            ),
          ),
        )
    );
  }

  void proceed() {
    if (! appState.checkPassword(passwordController.text) ){
      Fluttertoast.showToast(msg: TextConst.txtIncorrectPassword);
      return;
    }

    OptionsEditor.navigatorPushReplacement(context, passwordController.text);
  }
}
