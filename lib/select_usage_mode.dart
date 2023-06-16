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
  late _childNameList = <String>[];

  final _textControllerDeviceName = TextEditingController();
  late Map<String, List<String>> _childDeviceMap;
  
  bool _isStarting = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
	  _childDeviceMap = await appState.serverConnect.getChildDeviceMap(); 
	  _childNameList  = _childDeviceMap.keys.toList();

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
    
    final deviceNameList = _childDeviceMap[_textControllerChildName.text.toLowerCase()]??[];

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
                      // Child name
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
                            suffixIcon: _childNameList.isEmpty? null :
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
                              )
                        ),
                        onChanged: ((_) {
                          setState(() { });
                        }),
                      ),
                      
                      // Child device name
                      TextField(
                      controller: _textControllerChildDeviceName,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: TextConst.txtChildDeviceName,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(width: 3, color: Colors.blue),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        suffixIcon: deviceNameList.isEmpty? null :
                          PopupMenuButton<String>(
                            itemBuilder: (context) {
                            return deviceNameList.map<PopupMenuItem<String>>((deviceName) => PopupMenuItem<String>(
                              value: deviceName,
                              child: Text(deviceName),
                            )).toList();
                            },
                            onSelected: (deviceName) {
                            setState(() {
                              _textControllerDeviceName.text = deviceName != TextConst.txtAddNewDevice?deviceName:'';
                            });
                            },
                          )
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
      await appState.setUsingMode(_usingMode!, _textControllerChildName.text, _textControllerDeviceName.text);
      widget.onUsingModeSelectOk();
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }
}
