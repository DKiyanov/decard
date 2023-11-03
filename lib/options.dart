import 'package:decard/simple_menu.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'common.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Options extends StatefulWidget {
  final VoidCallback onOptionsOk;
  const Options({required this.onOptionsOk, Key? key}) : super(key: key);

  @override
  State<Options> createState() => _OptionsState();
}

class _OptionsState extends State<Options> {
  final _textControllerChildName  = TextEditingController();
  late List<String> _childNameList;

  final _textControllerDeviceName = TextEditingController();
  late Map<String, List<String>> _childDeviceMap;
  
  bool _isStarting = true;

  @override
  void dispose() {
    _textControllerChildName.dispose();
    _textControllerDeviceName.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
	  _childDeviceMap = await appState.serverFunctions.getChildDeviceMap();
	  _childNameList  = _childDeviceMap.keys.toList();

    final cdNames = await appState.serverFunctions.getChildDeviceFromDeviceID();
    if (cdNames != null) {
      _textControllerChildName.text = cdNames.childName;
      _textControllerDeviceName.text = cdNames.deviceName;
    }

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
    
    final deviceNameList = _childDeviceMap[_textControllerChildName.text]??[];

    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(TextConst.txtOptions),
        ),

        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: ListView(
                  children: [

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
                            popupMenu(
                                icon: const Icon(Icons.menu),
                                menuItemList: _childNameList.map<SimpleMenuItem>((childName) => SimpleMenuItem(
                                  child: Text(childName),
                                  onPress: () {
                                    setState(() {
                                      _textControllerChildName.text = childName != TextConst.txtAddNewChild?childName:'';
                                    });
                                  }
                                )).toList()
                            )
                      ),
                      onChanged: ((_) {
                        setState(() { });
                      }),
                    ),

                    Container(height: 10),

                    // Child device name
                    TextField(
                    controller: _textControllerDeviceName,
                    decoration: InputDecoration(
                      filled: true,
                      labelText: TextConst.txtDeviceName,
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(width: 3, color: Colors.blue),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      suffixIcon: deviceNameList.isEmpty? null :
                        popupMenu(
                            icon: const Icon(Icons.menu),
                            menuItemList: deviceNameList.map<SimpleMenuItem>((deviceName) => SimpleMenuItem(
                              child: Text(deviceName),
                              onPress: () {
                                setState(() {
                                  _textControllerDeviceName.text = deviceName != TextConst.txtAddNewDevice?deviceName:'';
                                });
                              }
                            )).toList()
                        )
                    ),
                    onChanged: ((_) {
                      setState(() { });
                    }),
                    ),

                    Container(height: 20),


                    ElevatedButton(onPressed: ()=> proceed(), child: Text(TextConst.txtProceed))

                  ],
                )
            )
        )
    );
  }

  Future<void> proceed() async {
    if (_textControllerChildName.text.isEmpty){
      Fluttertoast.showToast(msg: TextConst.txtInputChildName);
      return;
    }

    await appState.firstRunOkPrepare(_textControllerChildName.text, _textControllerDeviceName.text);

    widget.onOptionsOk.call();
  }
}
