import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:simple_events/simple_events.dart';
import 'package:sqflite/sqflite.dart';

import 'card_model.dart';
import 'db.dart';
import 'card_controller.dart';
import 'common.dart';
import 'file_source.dart';
import 'file_source_editor.dart';
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
  static const String _keyMinEarnValue     = 'minEarnValue';
  static const String _keyUploadStatUrl    = 'uploadStatUrl';
  static const String _keyLastUploadStatDT = 'lastUploadStatDT';

  static const String _keyEarned         = 'earned';

  static const String _keyAddEstimate = 'com.dkiyanov.learning_control.action.ADD_ESTIMATE';
  static const String _keyCoinTypeMinute = 'minute';


  static final AppState _instance = AppState._();

  late SharedPreferences prefs;

  final onChangeEarn = SimpleEvent();

  final _fileSourceList = <FileSource>[];
  late String _appDir;

  late String _coinSourceName;

  UsingMode? _usingMode;
  UsingMode get usingMode => _usingMode!;

  bool get firstRun => _usingMode == null;

  int _minEarnValue = 10;
  int get minEarnValue => _minEarnValue;
  set minEarnValue(int value) {
    if (_minEarnValue == value) return;
    _minEarnValue = value;
    prefs.setInt(_keyMinEarnValue, value);
  }

  FileSource? _uploadStatUrl;
  FileSource? get uploadStatUrl => _uploadStatUrl;

  int _lastUploadStatDT = 0;

  double _earned = 0;
  double get earned => _earned;

  late Database db;
  late DbSource dbSource;


  late ProcessCardController processCardController;
  late CardController cardController;

  late DataLoader _dataLoader;
  
  late Regulator regulator;

  factory AppState() {
    return _instance;
  }

  AppState._();

  Future<void> init() async {
    await _loadOptions();

    db = (await DBProvider.db.database)!;
    dbSource = DbSource(db);

    processCardController = ProcessCardController(db, dbSource.tabCardStat, dbSource.tabCardHead);
    await processCardController.init();

    cardController = CardController(
      dbSource             : dbSource,
      processCardController: processCardController,
    );

    cardController.onAddEarn.subscribe((listener, earn){
      addEarn(earn!);
    });

    regulator = Regulator.fromFile('$_appDir/regulator.json');
    _dataLoader = DataLoader(dbSource);

    if (await checkStoragePermission()) {
      scanFileSourceList(); // without await - it should not slow down the launch of the program
    }
    Timer.periodic(const Duration(hours: 1), (_) => scanFileSourceList());

    if (usingMode == UsingMode.testing) {
      appMode = AppMode.testing;
    }
  }

  Future<void> _loadOptions() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _coinSourceName = '${packageInfo.packageName}@${packageInfo.appName}';

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

      _earned = prefs.getDouble(_keyEarned)??0;

      _minEarnValue = prefs.getInt(_keyMinEarnValue)??minEarnValue;

      final fileSourceJson = prefs.getString(_keyUploadStatUrl)??'';
      if (fileSourceJson.isNotEmpty){
        _uploadStatUrl = FileSource.fromJson(jsonDecode(fileSourceJson));
      }

      _lastUploadStatDT = prefs.getInt(_keyLastUploadStatDT)??0;
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

    final errList = await scanNetworkFileSource(_fileSourceList, dbSource.tabSourceFile);

    final dirList = _fileSourceList.map((fileSource) => fileSource.localPath).toList();
    _dataLoader.refreshDB(dirForScanList: dirList, selfDir: _appDir);
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

  Future<bool> editUploadStatUrl(BuildContext context) async {
    final newFileSource = await FileSourceEditor.navigatorPush(context, TextConst.txtUploadStatUrl, _uploadStatUrl);
    if (newFileSource != null) {
      _uploadStatUrl = newFileSource;
      final fileSourceJson = jsonEncode( newFileSource.toJson());
      prefs.setString(_keyUploadStatUrl, fileSourceJson);
      return true;
    }
    return false;
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

  /// Выгрузка статистики
  Future<void> uploadStat() async {
    if (uploadStatUrl == null) return;

//    final fdt = DateTime.fromMillisecondsSinceEpoch(_lastUploadStatDT);
    final ndt = DateTime.now();

    // в результате должна получиться строка json
    //
    // данные должны быть за период с последней выгрузки по текущий момент
    // данные содержат:
    //   статистику за период:
    //     сколько карточек решено:
    //       правильно
    //       не правильно
    //     общее затраченное время
    //   текущее состояние по пакететам:
    //     время изучения (кол-во дней от даты начала)
    //     затраченное время (суммарное время по карточкам)
    //     сколько картоек изучено
    //     сколько осталось
    //     процен изучения
    //     сколько карточек в активном изучении

    final Map<String, dynamic> map = {};


    final jsonStr = jsonEncode(map);
    final listInt = jsonStr.codeUnits;
    final bytes = Uint8List.fromList(listInt);

    String fileName = ndt.toIso8601String();
    fileName.replaceAll(':', '-');

    uploadData(uploadStatUrl!, '$fileName.json', bytes);

    _lastUploadStatDT = ndt.millisecondsSinceEpoch;
    prefs.setInt(_keyLastUploadStatDT, _lastUploadStatDT);
  }

  /// testing and debugging the card selection algorithm
  Future<void> selfTest() async {
    const int daysCount = 100;
    const int maxCountTestPerDay = 100;
    const int speed = 20; // the number of shows for great memorization

    DateTime curDate = DateTime.now();

    final random = Random();

    await dbSource.tabCardStat.clear();
    await processCardController.init();

    final testCardController = CardController(
      dbSource: dbSource,
      processCardController: processCardController,
    );

    print('tstres start');

    for( var dayNum = 1 ; dayNum <= daysCount; dayNum++ ) {
      curDate = curDate.add(const Duration(days: 1));
      processCardController.setTestDate(curDate);

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

        await processCardController.registerResult(testCardController.card!.head.jsonFileID, testCardController.card!.head.cardID, result);

        final statData = await processCardController.getStatData(testCardController.card!.head.cardID);
        final cardStat = CardStat.fromMap(statData!);

        print('tstres; date ; ${dateToInt(curDate)}; cardKey ; ${testCardController.card!.head.cardKey}; result ; $result; testsCount ; ${cardStat.testsCount}; quality ; ${cardStat.quality}');
      }

    }

    print('tstres finish');
  }
}




















