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
        earnController.addEarn(earn!);
      });

      appMode = AppMode.testing;
    }

    if (usingMode == UsingMode.manager) {
      await _searchNewChildrenInServer();
    }

    synchronize();
  }

  Future<void> addChild(String childName) async {
    final lowChildName = childName.toLowerCase();
    if (childList.any((child) => child.name.toLowerCase() == lowChildName)) return;

    final child = Child(childName, _appDir);
    await child.init();

    childList.add(child);
  }

  /// инициализирует детей каталоги которых есть на устройстве
  Future<void> _initChildren() async {
    final dir = Directory(_appDir);
    final fileList = dir.listSync();
    for (var file in fileList) {
      if (file is Directory) {
        final childName = path_util.basename(file.path);
        if (childName == 'flutter_assets') continue;

        print(childName);
        await addChild(childName);
      }
    }
  }

  /// Поиск новых детей на сервере и заведение их локально
  Future<void> _searchNewChildrenInServer() async {
    final serverChildList = await appState.serverConnect.getChildList();

    for (var childName in serverChildList) {
      await addChild(childName);
    }
  }

  Future<void> setUsingMode(UsingMode newUsingMode, String childName) async {
    if (newUsingMode == UsingMode.testing) {
      final useChildName = await serverConnect.addChild(childName);
      await addChild(useChildName);
    }

    prefs.setString(_kUsingMode, newUsingMode.name);
    _usingMode = newUsingMode;

    await _initFinish();
  }

  Future<void> synchronize() async {
    final serverChildList = await serverConnect.getChildList();
    for (var childName in serverChildList) {
      final lowChildName = childName.toLowerCase();
      final child = childList.firstWhereOrNull((child) => child.name.toLowerCase() == lowChildName);
      if (child == null) continue;

      await serverConnect.synchronizeChild(child, childName);
      await _dataLoader.refreshDB(dirForScanList: [child.downloadDir], selfDir: child.cardsDir, dbSource: child.dbSource);
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

  /// тестирование и отладка алгоритма выбора карточек
  Future<void> selfTest(Child child) async {
    const int daysCount = 100;
    const int maxCountTestPerDay = 100;
    const int speed = 20; // колво показов для отличного запминания

    DateTime curDate = DateTime.now();

    final random = Random();

    await child.dbSource.tabCardStat.clear();
    await child.processCardController.init();

    final testCardController = CardController(
      dbSource: child.dbSource,
      processCardController: child.processCardController,
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

        // Вероятность правильного ответа ростёт по мере увеличения кол-ва тестов
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
  static const String _keyEarned         = 'earned';

  static const String _keyAddEstimate = 'com.dkiyanov.learning_control.action.ADD_ESTIMATE';
  static const String _keyCoinTypeMinute = 'minute';

  late String _coinSourceName;

  final SharedPreferences prefs;
  final PackageInfo packageInfo;

  final onChangeEarn = SimpleEvent();

  double _earned = 0;
  double get earned => _earned;

  EarnController(this.prefs, this.packageInfo) {
    _earned = prefs.getDouble(_keyEarned)??0;
    _coinSourceName = '${packageInfo.packageName}@${packageInfo.appName}';
  }

  void addEarn(double earn){
    _earned += earn;
    prefs.setDouble(_keyEarned, _earned);
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

  /// Рассылка уведомлений о зароботке
  Future<void> sendEarned() async {
    final minuteCount = _earned.truncate();

    _sendEstimateIntent(minuteCount);

    _earned = _earned - minuteCount;
    await prefs.setDouble(_keyEarned, _earned);

    onChangeEarn.send();
  }
}