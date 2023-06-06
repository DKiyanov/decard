import 'package:flutter/material.dart';

import 'app_state.dart';
import 'common.dart';
import 'options_editor.dart';

class UsingModeSelector extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context) async {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => const UsingModeSelector() ));
  }

  const UsingModeSelector({Key? key}) : super(key: key);

  @override
  State<UsingModeSelector> createState() => _UsingModeSelectorState();
}

class _UsingModeSelectorState extends State<UsingModeSelector> {
  UsingMode? _usingMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(TextConst.txtUsingModeTitle),
        ),

        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: ListView(
                  children: [
                    Card(
                        color: Colors.amberAccent,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(TextConst.txtUsingModeInvitation),
                        )
                    ),

                    ChoiceChip(
                      label: Text(TextConst.txtUsingModeTesting),
                      selected: _usingMode == UsingMode.testing,
                      onSelected: (value){
                        setState(() {
                          _usingMode = UsingMode.testing;
                        });
                      },
                      selectedColor: Colors.lightGreen,
                    ),

                    ChoiceChip(
                      label: Text(TextConst.txtUsingModeCardEdit),
                      selected: _usingMode == UsingMode.manager,
                      onSelected: (value){
                        setState(() {
                          _usingMode = UsingMode.manager;
                        });
                      },
                      selectedColor: Colors.lightGreen,
                    ),

                    ElevatedButton(onPressed: _usingMode != null? ()=> proceed(): null, child: Text(TextConst.txtProceed))

                  ],
                )
            )
        )
    );
  }

  Future<void> proceed() async {
    if (_usingMode == UsingMode.testing){
      OptionsEditor.navigatorPush(context).then((ok) {
        if (ok) {
          appState.setUsingMode(_usingMode!);
        }
      });
    }

    if (_usingMode == UsingMode.manager){
      appState.setUsingMode(_usingMode!);
      // TODO navigate to child list
    }
  }
}