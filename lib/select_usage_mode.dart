import 'package:flutter/material.dart';

import 'app_state.dart';
import 'common.dart';
import 'package:fluttertoast/fluttertoast.dart';

class UsingModeSelector extends StatefulWidget {
  final VoidCallback onUsingModeSelectOk;
  const UsingModeSelector({required this.onUsingModeSelectOk, Key? key}) : super(key: key);

  @override
  State<UsingModeSelector> createState() => _UsingModeSelectorState();
}

class _UsingModeSelectorState extends State<UsingModeSelector> {
  UsingMode? _usingMode;
  final _textControllerChildName  = TextEditingController();
  final _childNameList = <String>[];

  bool _isStarting = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    final childList = await appState.serverConnect.getChildList();
    _childNameList.clear();
    _childNameList.addAll(childList);
    _childNameList.add(TextConst.txtAddNewChild);

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

                    if (_usingMode == UsingMode.testing) ...[
                      TextField(
                        controller: _textControllerChildName,
                        decoration: InputDecoration(
                            filled: true,
                            labelText: TextConst.txtChildName,
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(width: 3, color: Colors.blue),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            suffixIcon: _childNameList.isNotEmpty?
                            PopupMenuButton<String>(
                              itemBuilder: (context) {
                                return _childNameList.map<PopupMenuItem<String>>((childName) => PopupMenuItem<String>(
                                  value: childName,
                                  child: Text(childName),
                                )).toList();
                              },
                              onSelected: (childName) {
                                setState(() {
                                  _textControllerChildName.text = childName != TextConst.txtAddNewChild?childName:'';
                                });
                              },
                            ): null
                        ),
                        onChanged: ((_) {
                          setState(() { });
                        }),
                      ),
                    ],

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
    if (_usingMode == UsingMode.testing) {
      if (_textControllerChildName.text.isEmpty){
        Fluttertoast.showToast(msg: TextConst.txtInputChildName);
        return;
      }
    }

    try {
      await appState.setUsingMode(_usingMode!, _textControllerChildName.text);
      widget.onUsingModeSelectOk();
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }
}