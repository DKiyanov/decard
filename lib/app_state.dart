import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:decard/parse_connect.dart';
import 'package:decard/platform_service.dart';
import 'package:decard/server_functions.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:simple_events/simple_events.dart';

import 'child.dart';
import 'common.dart';
import 'package:path/path.dart' as path_util;

final appState = AppState();

class AppState {
  static final AppState _instance = AppState._();

  late SharedPreferences prefs;
  late PackageInfo packageInfo;

  late String _appDir;

  late ParseConnect serverConnect;
  late ServerFunctions serverFunctions;

  final childList = <Child>[];

  late EarnController earnController;

  factory AppState() {
    return _instance;
  }

  AppState._();

  Future<void> initialization(ParseConnect serverConnect, LoginMode loginMode) async {
    this.serverConnect = serverConnect;

    prefs = await SharedPreferences.getInstance();

    packageInfo = await PackageInfo.fromPlatform();

    Directory appDocDir = await getApplicationDocumentsDirectory();
    _appDir =  appDocDir.path;

    serverFunctions = ServerFunctions(serverConnect.serverURL, serverConnect.user!.objectId!);

    await _initFinish();
  }

  Future<void> _initFinish() async {
    await _initChildren();

    if (childList.isNotEmpty) {
      earnController = EarnController(prefs, packageInfo);

      earnController.onSendEarn.subscribe((listener, data) {
        childList.first.saveTestsResultsToServer(serverFunctions);
      });

      childList.first.cardController.onAddEarn.subscribe((listener, earn){
        earnController.addEarn(earn!);
      });
    }

    await synchronize();
  }

  /// add new child if it not exists
  /// return new or exists child
  Future<Child> addChild(String childName, String deviceName) async {
    final child = childList.firstWhereOrNull((child) => child.name == childName && child.deviceName == deviceName);
    if (child != null) return child;

    final newChild = Child(childName, deviceName, _appDir, prefs);
    await newChild.init();

    childList.add(newChild);
    return newChild;
  }

  /// Initializes children whose directories are on the device
  Future<void> _initChildren() async {
    final dir = Directory(_appDir);
    final fileList = dir.listSync();
    for (var file in fileList) {
      if (file is Directory) {
        final dirName = path_util.basename(file.path);
        if (dirName == 'flutter_assets') continue;
        final names = Child.getNamesFromDir(dirName);
        await addChild(names.childName, names.deviceName);
      }
    }

    childList.sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> firstRunOkPrepare(String childName, String deviceName) async {
    final names = await serverFunctions.addChildDevice(childName, deviceName);
    final child = await addChild(names.childName, names.deviceName);

    await _initFinish();

    child.updateStatFromServer(serverFunctions);
  }

  Future<void> synchronize() async {
    final serverChildMap = await serverFunctions.getChildDeviceMap();
    for (var childName in serverChildMap.keys) {
      final deviceList = serverChildMap[childName]!;

      for (var deviceName in deviceList) {
        final child = childList.firstWhereOrNull((child) => child.name == childName && child.deviceName == deviceName);
        if (child == null) continue;

        await child.synchronize(serverFunctions);
      }
    }
  }

  Future<void> errorsDialog(BuildContext context, List<String> errorList, String title) async {
    if (errorList.isEmpty) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
                children: errorList.map((str) => Text(str)).toList()
            ),
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent,),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<String> getDeviceID() async {
    return await PlatformService.getDeviceID();
  }
}

class EarnController {
  static const String _keyEarnedSeconds = 'earned';

  static const String _keyAddEstimate = 'com.dkiyanov.learning_control.action.ADD_ESTIMATE';
  static const String _keyCoinTypeMinute = 'minute';

  late String _coinSourceName;

  final SharedPreferences prefs;
  final PackageInfo packageInfo;

  final onChangeEarn = SimpleEvent();
  final onSendEarn = SimpleEvent();

  double _earnedSeconds = 0;
  double get earnedSeconds => _earnedSeconds;

  EarnController(this.prefs, this.packageInfo) {
    _earnedSeconds = prefs.getDouble(_keyEarnedSeconds)??0;
    _coinSourceName = '${packageInfo.packageName}@${packageInfo.appName}';
  }

  void addEarn(double earnSeconds){
    _earnedSeconds += earnSeconds;
    prefs.setDouble(_keyEarnedSeconds, _earnedSeconds);
    onChangeEarn.send();
  }

  Future<void> _sendEstimateIntent(int minuteCount) async {
    await sendBroadcast(
      BroadcastMessage(
          name: _keyAddEstimate,
          data: {
            "CoinSourceName" : _coinSourceName,
            "CoinType"       : _keyCoinTypeMinute,
            "CoinCount"      : minuteCount,
          }
      ),
    );
  }

  /// Sending notifications of earnings
  Future<void> sendEarned() async {
    final minuteCount = (_earnedSeconds / 60).truncate();

    _sendEstimateIntent(minuteCount);

    onSendEarn.send();

    _earnedSeconds = _earnedSeconds - minuteCount * 60;
    await prefs.setDouble(_keyEarnedSeconds, _earnedSeconds);

    onChangeEarn.send();
  }
}