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
import 'file_source.dart';
import 'file_source_list_editor.dart';
import 'loader.dart';
import 'net_file_source_scan.dart';

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
  static const String _keyUsingMode        = 'usingMode';
  static const String _keyPassword         = 'password';
  static const String _keyFileSourceList   = 'fileSourceList';

  static final AppState _instance = AppState._();

  late SharedPreferences prefs;
  late PackageInfo packageInfo;

  final _fileSourceList = <FileSource>[];
  late String _appDir;

  UsingMode? _usingMode;
  UsingMode get usingMode => _usingMode!;

  bool get firstRun => _usingMode == null;

  late DataLoader _dataLoader;

  late Child curChild;

  late EarnController earnController;

  factory AppState() {
    return _instance;
  }

  AppState._();

  Future<void> init() async {
    await _loadOptions();

    curChild = Child('child', _appDir);
    await curChild.init();

    earnController = EarnController(prefs, packageInfo);

    curChild.cardController.onAddEarn.subscribe((listener, earn){
      earnController.addEarn(earn!);
    });

    _dataLoader = DataLoader();

    if (await checkStoragePermission()) {
      scanFileSourceList(); // без await - оно не должно тормозить запуск программы
    }
    Timer.periodic(const Duration(hours: 1), (_) => scanFileSourceList());

    if (usingMode == UsingMode.testing) {
      appMode = AppMode.testing;
    }
  }

  Future<void> _loadOptions() async {
    packageInfo = await PackageInfo.fromPlatform();

    Directory appDocDir = await getApplicationDocumentsDirectory();
    _appDir =  appDocDir.path;

    prefs = await SharedPreferences.getInstance();
//    _prefs.clear(); // for debug

    final usingModeStr = prefs.getString(_keyUsingMode)??'';
    if (usingModeStr.isEmpty){ // first run
      await initFileSourceList();
    } else {
      _usingMode = UsingMode.values.firstWhere((usingMode) => usingMode.name == usingModeStr);

      _fileSourceList.clear();
      final stringList = prefs.getStringList(_keyFileSourceList)??[];
      final fileSourceList = stringList.map<FileSource>((jsonStr) => FileSource.fromJson(jsonDecode(jsonStr))).toList();
      _fileSourceList.addAll(fileSourceList);


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

  Future<void> initFileSourceList() async {
    _fileSourceList.clear();

    // https://stackoverflow.com/questions/72530115/flutter-download-a-file-from-url-automatically-to-downloads-directory

    if (!await checkStoragePermission()) return;

    // final status = await Permission.storage.status;
    // if (status != PermissionStatus.granted) {
    //   final result = await Permission.storage.request();
    //   if (result != PermissionStatus.granted) {
    //     return;
    //   }
    // }

    // {
    //   final status = await Permission.manageExternalStorage.status;
    //   if (status != PermissionStatus.granted) {
    //     final result = await Permission.manageExternalStorage.request();
    //     if (result != PermissionStatus.granted) {
    //       return;
    //     }
    //   }
    // }

    final downloadDirList = await getExternalStorageDirectories();
    if (downloadDirList == null || downloadDirList.isEmpty) return;

    for (var dir in downloadDirList) {
      final path = dir.path;
      final pos = path.indexOf('Android/data');
      if (pos < 0) continue;

      final downloadPath = '${path.substring(0,pos)}Download';
      if (_fileSourceList.any((fileSource) => fileSource.url == downloadPath)) continue;

      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) continue;

      _fileSourceList.add(FileSource(type: FileSourceType.localPath, url: downloadPath));
    }

    _saveFileSourceList();
  }

  Future<void> editFileSourceList(BuildContext context) async {
    final newFileSourceList = await FileSourceListEditor.navigatorPush(context, _fileSourceList);
    if (newFileSourceList == null) return;

    await prepareLocalPath(newFileSourceList, _appDir);

    _fileSourceList.clear();
    _fileSourceList.addAll(newFileSourceList);
    _saveFileSourceList();
  }

  Future<void> _saveFileSourceList() async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = _fileSourceList.map((fileSource) => jsonEncode(fileSource.toJson())).toList();
    await prefs.setStringList(_keyFileSourceList, stringList);
  }

  bool _scanningOnProcess = false;
  bool get scanningOnProcess => _scanningOnProcess;
  final scanErrList = <String>[];

  late AppMode appMode;

  Future<void> scanFileSourceList() async {
    if (_scanningOnProcess) return;
    _scanningOnProcess = true;

    final errList = await scanNetworkFileSource(_fileSourceList, curChild.dbSource.tabSourceFile);

    final dirList = _fileSourceList.map((fileSource) => fileSource.localPath).toList();
    _dataLoader.refreshDB(dirForScanList: dirList, selfDir: _appDir, dbSource: curChild.dbSource);
    errList.addAll(_dataLoader.errorList);

    scanErrList.clear();
    scanErrList.addAll(errList);

    _scanningOnProcess = false;
  }

  Future<void> scanErrorsDialog(BuildContext context) async {
    if (scanErrList.isEmpty) return;
    await errorsDialog(context, scanErrList, TextConst.txtUploadErrorInfo);
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
    prefs.setString(_keyUsingMode, usingMode.name);
  }

  String _getHash(String str) {
    final bytes = utf8.encode(str);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Установка пароля
  Future<void> setPassword(String password) async {
    final hash = _getHash(password);
    await prefs.setString(_keyPassword, hash);
  }

  /// Проверка пароля
  bool checkPassword(String password) {
    final savedHash = prefs.getString(_keyPassword)??'';
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