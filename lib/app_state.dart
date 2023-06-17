import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:decard/server_connect.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:simple_events/simple_events.dart';

import 'card_model.dart';
import 'child.dart';
import 'card_controller.dart';
import 'common.dart';
import 'loader.dart';
import 'package:path/path.dart' as path_util;

enum UsingMode {
  testing,
  manager
}

enum AppMode {
  testing,
  demo,
}

final appState = AppState();

class AppState {
  static const String _kUsingMode = 'usingMode';

  static final AppState _instance = AppState._();

  late SharedPreferences prefs;
  late PackageInfo packageInfo;

  late String _appDir;

  UsingMode? _usingMode;
  UsingMode get usingMode => _usingMode!;

  bool get firstRun => _usingMode == null;

  late DataLoader _dataLoader;

  late ServerConnect serverConnect;

  final childList = <Child>[];

  late EarnController earnController;

  late AppMode appMode;

  factory AppState() {
    return _instance;
  }

  AppState._();

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    packageInfo = await PackageInfo.fromPlatform();

    Directory appDocDir = await getApplicationDocumentsDirectory();
    _appDir =  appDocDir.path;

    serverConnect = ServerConnect(prefs);

    _dataLoader = DataLoader();

    final usingModeStr = prefs.getString(_kUsingMode)??'';
    if (usingModeStr.isEmpty) return; // first run

    _usingMode = UsingMode.values.firstWhere((usingMode) => usingMode.name == usingModeStr);

    await _initFinish();
  }

  Future<void> _initFinish() async {
    await _initChildren();

    if (usingMode == UsingMode.testing) {
      earnController = EarnController(prefs, packageInfo);

      childList.first.cardController.onAddEarn.subscribe((listener, earn){
        serverConnect.saveTestsResults(childList.first);
        earnController.addEarn(earn!);
      });

      appMode = AppMode.testing;
    }

    if (usingMode == UsingMode.manager) {
      await _searchNewChildrenInServer();
    }

    synchronize();
  }

  Future<void> addChild(String childName, String deviceName) async {
    if (childList.any((child) => child.name == childName && child.deviceName == deviceName )) return;

    final child = Child(childName, deviceName, _appDir, _dataLoader);
    await child.init();

    childList.add(child);
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
  }

  /// Search for new children on the server and create them locally
  Future<void> _searchNewChildrenInServer() async {
    final serverChildMap = await appState.serverConnect.getChildDeviceMap();

    for (var childName in serverChildMap.keys) {
      final deviceList = serverChildMap[childName]!;
      for (var deviceName in deviceList) {
        await addChild(childName, deviceName);
      }
    }
  }

  Future<void> setUsingMode(UsingMode newUsingMode, String childName, String deviceName) async {
    if (newUsingMode == UsingMode.testing) {
      final names = await serverConnect.addChildDevice(childName, deviceName);
      await addChild(names.childName, names.deviceName);
    }

    prefs.setString(_kUsingMode, newUsingMode.name);
    _usingMode = newUsingMode;

    await _initFinish();
  }

  Future<void> synchronize() async {
    final serverChildMap = await serverConnect.getChildDeviceMap();
    for (var childName in serverChildMap.keys) {
      final deviceList = serverChildMap[childName]!;

      for (var deviceName in deviceList) {
        final child = childList.firstWhereOrNull((child) => child.name == childName && child.deviceName == deviceName);
        if (child == null) continue;

        await serverConnect.synchronizeChild(child);
      }
    }
  }

  Future<bool> checkStoragePermission() async {
    final status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      final result = await Permission.storage.request();
      if (result != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
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

  /// testing and debugging the card selection algorithm
  Future<void> selfTest(Child child) async {
    const int daysCount = 100;
    const int maxCountTestPerDay = 100;
    const int speed = 20; // number of shows for great memory

    DateTime curDate = DateTime.now();

    final random = Random();

    await child.dbSource.tabCardStat.clear();
    await child.processCardController.init();

    final testCardController = CardController(
      dbSource: child.dbSource,
      processCardController: child.processCardController,
      regulator: child.regulator,
    );

    print('tstres start');

    for( var dayNum = 1 ; dayNum <= daysCount; dayNum++ ) {
      curDate = curDate.add(const Duration(days: 1));
      child.processCardController.setTestDate(curDate);

      final testsCount =  random.nextInt(maxCountTestPerDay);

      for( var testNum = 1 ; testNum <= testsCount; testNum++ ) {
        final cardSelected = await testCardController.selectNextCard();
        if (!cardSelected) return;

        final rnd = random.nextInt(100);
        bool result = false;

        // The probability of a correct answer increases as the number of tests increases
        if (testCardController.card!.stat.testsCount < speed) {
          result = rnd <= 100 * ( testCardController.card!.stat.testsCount / speed );
        } else {
          result = rnd <= 98;
        }

        await child.processCardController.registerResult(testCardController.card!.head.jsonFileID, testCardController.card!.head.cardID, result);

        final statData = await child.processCardController.getStatData(testCardController.card!.head.cardID);
        final cardStat = CardStat.fromMap(statData!);

        print('tstres; date ; ${dateToInt(curDate)}; cardKey ; ${testCardController.card!.head.cardKey}; result ; $result; testsCount ; ${cardStat.testsCount}; quality ; ${cardStat.quality}');
      }

    }

    print('tstres finish');
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

    _earnedSeconds = _earnedSeconds - minuteCount * 60;
    await prefs.setDouble(_keyEarnedSeconds, _earnedSeconds);

    onChangeEarn.send();
  }
}