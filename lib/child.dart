import 'dart:io';

import 'package:decard/db_flt.dart';
import 'package:decard/regulator.dart';
import 'package:decard/server_functions.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_util;

import 'card_controller.dart';
import 'card_model.dart';
import 'card_process_controller.dart';
import 'common_func.dart';
import 'db.dart';
import 'local_pack_load.dart';

class ChildAndDeviceNames {
  final String childName;
  final String deviceName;
  ChildAndDeviceNames(this.childName, this.deviceName);
}

class Child {
  static const String regulatorFileName = 'regulator.json';
  static const String namesSeparator = '@';
  static const String _kLastStatDate = 'lastStatDate';

  final String appDir;
  final String name;
  final String deviceName;

  late Database db;
  late DbSource dbSource;

  late ProcessCardController processCardController;
  late CardController cardController;

  Regulator? _regulator;
  Regulator get regulator => _regulator!;

  late String regulatorPath;

  late String rootDir;
  late String downloadDir;
  late String cardsDir;

  final cardResultList = <TestResult>[];

  ChildTestResults? _testResults;
  Future<ChildTestResults> get testResults async {
    if (_testResults != null) return _testResults!;
    _testResults = ChildTestResults(this);
    await _testResults!.init();
    return _testResults!;
  }

  final SharedPreferences prefs;

  int _lastStatDate = 0;

  final localPackLoader = LocalPackLoader();

  Child(this.name, this.deviceName, this.appDir, this.prefs);

  Future<void> init() async {
    rootDir = join(appDir, '$name$namesSeparator$deviceName');

    final dbDir = await Directory( join(rootDir, 'db') ).create(recursive : true);

    downloadDir = (await Directory( join(rootDir, 'download') ).create()).path;
    cardsDir    = (await Directory( join(rootDir, 'cards') ).create()).path;

    final dbSourceFlt = await DbSourceFlt.create(dbDir.path);
    db = dbSourceFlt.db;
    dbSource = dbSourceFlt;

    regulatorPath = join(rootDir, regulatorFileName );
    _regulator = await Regulator.fromFile( regulatorPath );
    _regulator!.fillDifficultyLevels();

    processCardController = ProcessCardController(db, regulator, dbSource.tabCardStat, dbSource.tabCardHead);
    await processCardController.init();

    cardController = CardController(
      dbSource: dbSource,
      regulator: regulator,
      onSelectNextCard: _selectNextCard,
      onSetCard: (jsonFileID, cardID) {
        processCardController.setCard(jsonFileID, cardID);
      },
      onCardResult: _onCardResult,
    );

    _lastStatDate = prefs.getInt(_kLastStatDate)??0;
  }

  Future<CardPointer?> _selectNextCard() async {
    CardPointer? newCard;

    for (int i = 0; i < 10; i++) { // so that the last issued card is not reissued
      newCard = await processCardController.getCardForTest();
      if (newCard == null) return null;

      if (cardController.card?.head.cardID != newCard.cardID || cardController.card?.head.jsonFileID != newCard.jsonFileID){
        break;
      }
    }

    if (newCard == null) return null;
    return CardPointer( newCard.jsonFileID, newCard.cardID );
  }

  void _onCardResult(CardData card, CardParam cardParam, bool result, int tryCount, int solveTime, double earned) async {
    final newStat = await processCardController.registerResult(card.head.jsonFileID, card.head.cardID, result);

    final testResult = TestResult(
        fileGuid      : card.pacInfo.guid,
        fileVersion   : card.pacInfo.version,
        cardID        : card.head.cardKey,
        bodyNum       : card.body.bodyNum,
        result        : result,
        earned        : earned,
        tryCount      : tryCount,
        solveTime     : solveTime,
        dateTime      : dateTimeToInt(DateTime.now()),
        qualityBefore : card.stat.quality,
        qualityAfter  : newStat.quality,
        difficulty    : card.head.difficulty
    );

    cardResultList.add(testResult);
    dbSource.tabTestResult.insertRow(testResult);
  }

  Future<void> refreshRegulator() async {
    _regulator = await Regulator.fromFile( regulatorPath );
    _regulator!.fillDifficultyLevels();
    _regulator!.applySetListToDB(dbSource);
  }

  Future<void> refreshCardsDB([List<String>? dirForScanList]) async {
    dirForScanList ??= [downloadDir];
    await localPackLoader.refreshDB(dirForScanList: dirForScanList, selfDir: cardsDir, dbSource: dbSource);
  }

  /// Synchronizes the contents of the child's directories on the server and on the device
  /// Server -> Child
  /// missing directories, on server or device - NOT created
  Future<void> synchronize(ServerFunctions serverConnect) async {
    final fileList = await serverConnect.synchronizeChild(this);

    bool updateRegulator = false;
    if (fileList.contains(regulatorFileName)) {
      final regFile = File(path_util.join(downloadDir, regulatorFileName));
      regFile.renameSync(path_util.join(rootDir, regulatorFileName));
      updateRegulator = true;
      fileList.remove(regulatorFileName);
    }

    if (fileList.isNotEmpty) {
      await refreshCardsDB();
    }

    if (updateRegulator) {
      await refreshRegulator();
    }
  }

  /// saves tests results to server
  Future<void> saveTestsResultsToServer(ServerFunctions serverConnect) async {
    serverConnect.saveTestsResults(this);

    final curDate = dateToInt(DateTime.now());
    if (_lastStatDate >= curDate) return;

    await serverConnect.saveStatToServer(this);
    _lastStatDate = curDate;
    await prefs.setInt(_kLastStatDate, _lastStatDate);
  }

  /// load last test results from server
  Future<void> updateTestResultFromServer(ServerFunctions serverConnect) async {
    final from = await dbSource.tabTestResult.getLastTime();
    final to   = dateTimeToInt(DateTime.now());

    final testResultList = await serverConnect.getTestsResultsFromServer(this, from, to);

    for (var testResult in testResultList) {
      dbSource.tabTestResult.insertRow(testResult);
    }

    await updateStatFromServer(serverConnect);
  }

  /// load stat data from server
  /// to download statistics to the parent device
  /// to download statistics to the child's device when installing the application
  Future<void> updateStatFromServer(ServerFunctions serverConnect) async {
    final curDate = dateToInt(DateTime.now());
    if (_lastStatDate >= curDate) return;

    final newLastDate = await serverConnect.updateStatFromServer(this, _lastStatDate);
    if (newLastDate == 0) return;

    _lastStatDate = newLastDate;
    await prefs.setInt(_kLastStatDate, _lastStatDate);
  }

  static ChildAndDeviceNames getNamesFromDir(String dirName){
    final sub = dirName.split(namesSeparator);
    return ChildAndDeviceNames(sub.first, sub.last);
  }
}

class ChildTestResults {
  static const int _statDayCount = 10;

  final Child child;

  late DateTime firstDate;
  late DateTime lastDate;

  late int _firstTime;
  late int _lastTime;

  int _fromDate = 0;
  int _toDate = 0;

  DateTime get fromDate => intDateTimeToDateTime(_fromDate);
  DateTime get toDate   => intDateTimeToDateTime(_toDate);

  final resultList = <TestResult>[];

  ChildTestResults(this.child);

  Future<void> init() async {
    final now = DateTime.now();

    _firstTime = await child.dbSource.tabTestResult.getFirstTime();
    if (_firstTime > 0) {
      firstDate = intDateTimeToDateTime(_firstTime);
    } else {
      firstDate = now;
    }

    _lastTime = await child.dbSource.tabTestResult.getLastTime();
    if (_lastTime > 0) {
      lastDate = intDateTimeToDateTime(_lastTime);
    } else {
      lastDate = now;
    }

    final prev = now.add(const Duration(days: - _statDayCount));

    int fromDate = 0;
    int toDate = 0;

    fromDate = dateTimeToInt(DateTime(prev.year, prev.month, prev.day));
    toDate   = dateTimeToInt(now); // for end of current day

    await getData(fromDate, toDate);
  }

  Future<void> getData(int fromDate, int toDate) async {
    final time = toDate % 1000000;
    toDate = toDate - time;
    toDate += 240000;

    if (fromDate < _firstTime) fromDate = _firstTime;
    if (toDate   > _lastTime ) toDate   = _lastTime;

    if (_fromDate == fromDate && _toDate == toDate) return;

    _fromDate = fromDate;
    _toDate = toDate;

    resultList.clear();
    resultList.addAll( await child.dbSource.tabTestResult.getForPeriod(_fromDate, _toDate) );
  }

  Future<bool> pickedFromDate (BuildContext context) async {
    final pickedDate = await showDatePicker(
      context     : context,
      initialDate : intDateTimeToDateTime(_fromDate),
      firstDate   : firstDate,
      lastDate    : lastDate,
    );

    if (pickedDate == null) return false;

    final fromDate = dateTimeToInt(pickedDate);
    await getData(fromDate, _toDate);
    return true;
  }

  Future<bool> pickedToDate (BuildContext context) async {
    final pickedDate = await showDatePicker(
      context     : context,
      initialDate : intDateTimeToDateTime(_toDate),
      firstDate   : firstDate,
      lastDate    : lastDate,
    );

    if (pickedDate == null) return false;

    final toDate = dateTimeToInt(pickedDate);
    await getData(_fromDate, toDate);
    return true;
  }
}