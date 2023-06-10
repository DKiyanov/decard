import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:simple_events/simple_events.dart';

import 'card_model.dart';
import 'child.dart';
import 'card_controller.dart';
import 'common.dart';
import 'loader.dart';

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
  static const String _kUsingMode        = 'usingMode';
  static const String _kPassword         = 'password';

  static final AppState _instance = AppState._();

  late SharedPreferences prefs;
  late PackageInfo packageInfo;

  late String _appDir;

  UsingMode? _usingMode;
  UsingMode get usingMode => _usingMode!;

  bool get firstRun => _usingMode == null;

  late DataLoader _dataLoader;

  late Child curChild;

  late EarnController earnController;

  late AppMode appMode;

  factory AppState() {
    return _instance;
  }

  AppState._();

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    final usingModeStr = prefs.getString(_kUsingMode)??'';
    if (usingModeStr.isEmpty) return; // first run
    _usingMode = UsingMode.values.firstWhere((usingMode) => usingMode.name == usingModeStr);

    packageInfo = await PackageInfo.fromPlatform();

    Directory appDocDir = await getApplicationDocumentsDirectory();
    _appDir =  appDocDir.path;

    curChild = Child('child', _appDir);
    await curChild.init();

    earnController = EarnController(prefs, packageInfo);

    curChild.cardController.onAddEarn.subscribe((listener, earn){
      earnController.addEarn(earn!);
    });

    _dataLoader = DataLoader();

    if (usingMode == UsingMode.testing) {
      appMode = AppMode.testing;
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

  Future<void> setUsingMode(UsingMode usingMode) async {
    prefs.setString(_kUsingMode, usingMode.name);
  }

  String _getHash(String str) {
    final bytes = utf8.encode(str);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Установка пароля
  Future<void> setPassword(String password) async {
    final hash = _getHash(password);
    await prefs.setString(_kPassword, hash);
  }

  /// Проверка пароля
  bool checkPassword(String password) {
    final savedHash = prefs.getString(_kPassword)??'';
    final hash = _getHash(password);
    return savedHash == hash;
  }

  /// тестирование и отладка алгоритма выбора карточек
  Future<void> selfTest() async {
    const int daysCount = 100;
    const int maxCountTestPerDay = 100;
    const int speed = 20; // колво показов для отличного запминания

    DateTime curDate = DateTime.now();

    final random = Random();

    await curChild.dbSource.tabCardStat.clear();
    await curChild.processCardController.init();

    final testCardController = CardController(
      dbSource: curChild.dbSource,
      processCardController: curChild.processCardController,
    );

    print('tstres start');

    for( var dayNum = 1 ; dayNum <= daysCount; dayNum++ ) {
      curDate = curDate.add(const Duration(days: 1));
      curChild.processCardController.setTestDate(curDate);

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

        await curChild.processCardController.registerResult(testCardController.card!.head.jsonFileID, testCardController.card!.head.cardID, result);

        final statData = await curChild.processCardController.getStatData(testCardController.card!.head.cardID);
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