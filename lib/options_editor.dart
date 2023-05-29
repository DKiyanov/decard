import 'package:decard/app_state.dart';
import 'package:decard/card_testing.dart';
import 'package:flutter/material.dart';

import 'common.dart';

class OptionsEditor extends StatefulWidget {
  static Future<bool> navigatorPushReplacement(BuildContext context, [String password = '']) async {
    return await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OptionsEditor(password: password) ))??true;
  }
  static Future<bool> navigatorPush(BuildContext context, [String password = '']) async {
    return await Navigator.push(context, MaterialPageRoute(builder: (_) => OptionsEditor(password: password) ))??true;
  }

  final String password;

  const OptionsEditor({Key? key, this.password = ''}) : super(key: key);

  @override
  State<OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<OptionsEditor> {
  final _passwordController      = TextEditingController();
  final _minEarnController       = TextEditingController();
  final _uploadStatUrlController = TextEditingController();

  bool    _obscureText       = true;
  bool    _firstPasswordShow = true;
  String? _passwordError;
  bool    _passwordChanged   = false;
  String? _minEarnError;

  @override
  void initState() {
    super.initState();
    _minEarnController.text = '${appState.minEarnValue}';
    _uploadStatUrlController.text = appState.uploadStatUrl?.url??'';
    if (!appState.firstRun) _passwordController.text = widget.password;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
            Navigator.pop(context, false);
          }),
          centerTitle: true,
          title: Text(TextConst.txtOptions),
          actions: [
            IconButton(
                icon: const Icon(Icons.check, color: Colors.lightGreen),
                onPressed: _onOkExit
            )
          ],
        ),

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: [
                Container(height: 10),

                // Поле ввода - виличина минимального зароботка
                TextField(
                  controller: _minEarnController,
                  keyboardType: TextInputType.number,

                  decoration: InputDecoration(
                    labelText: TextConst.txtMinEarnInput,
                    helperText: TextConst.txtMinEarnHelp,
                    helperMaxLines: 2,
                    errorText: _minEarnError,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.blue),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.red),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.red),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),

                Container(height: 20),

                // Поле ввода - Адрес для выгрузки статистики
                TextField(
                  controller: _uploadStatUrlController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: TextConst.txtUploadStatUrl,
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
                      icon: const Icon(Icons.arrow_right, color: Colors.green),
                      onPressed: ()=> _onUploadStatUrlEdit(),
                    ),
                  ),
                  onChanged: (text){
                    if (_minEarnError != null) {
                      setState(() {
                        _minEarnError = null;
                      });
                    }
                  },
                ),

                Container(height: 20),

                // Кнопка - настройка источников файлов
                ElevatedButton(
                    onPressed: _onPressEditFileSource,
                    child: Text(TextConst.txtTuningFileSourceList)
                ),

                Container(height: 30),

                // Поле ввода - изенение пароля
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  enableSuggestions: false,
                  autocorrect: false,

                  decoration: InputDecoration(
                    labelText: TextConst.txtChangingPassword,
                    helperText: TextConst.txtPasswordJustification,
                    errorText: _passwordError,
                    helperMaxLines: 2,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.blue),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.red),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 3, color: Colors.red),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    suffixIcon : IconButton(
                      icon: Icon(_obscureText? Icons.abc : Icons.password),
                      onPressed: ()=> {
                        setState((){
                          _obscureText = !_obscureText;
                          if (!_obscureText && _firstPasswordShow) {
                            _firstPasswordShow = false;
                            _passwordController.text = '';
                          }
                        })
                      },
                    ),
                  ),
                  onChanged: (text){
                    _passwordChanged = true;
                    if (_passwordError != null) {
                      setState(() {
                        _passwordError = null;
                      });
                    }
                  },
                ),



              ],
            ),
          ),
        )
    );
  }

  Future<void> _onPressEditFileSource() async {
    await appState.editFileSourceList(context);
    await appState.scanFileSourceList();
    if (mounted){
      appState.scanErrorsDialog(context);
    }
  }

  Future<void> _onUploadStatUrlEdit() async {
    if (await appState.editUploadStatUrl(context)) {
      setState(() {
        _uploadStatUrlController.text = appState.uploadStatUrl?.url??'';
      });
    }
  }

  void _onOkExit() {
    _passwordError = null;
    _minEarnError = null;

    if (_passwordController.text.isEmpty) {
      _passwordError = TextConst.errPasswordIsEmpty;
    }

    if (_minEarnController.text.isEmpty) {
      _minEarnError = TextConst.errSetMinEarn;
    }

    try {
      appState.minEarnValue = int.parse(_minEarnController.text);
    } catch (e){
      _minEarnError = TextConst.errInvalidValue;
    }

    if (_minEarnError != null || _passwordError != null) {
      setState(() {});
      return;
    }

    if (_passwordChanged) {
      appState.setPassword(_passwordController.text);
    }

    if (appState.firstRun) {
      DeCard.navigatorPushReplacement(context);
      return;
    }

    Navigator.pop(context, true);
  }
}
