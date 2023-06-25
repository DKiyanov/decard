import 'dart:io';

import 'package:decard/regulator.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'card_controller.dart';
import 'db.dart';
import 'loader.dart';

class ChildAndDeviceNames {
  final String childName;
  final String deviceName;
  ChildAndDeviceNames(this.childName, this.deviceName);
}

class Child {
  static String regulatorFileName = 'regulator.json';
  static String namesSeparator = '@';

  final String appDir;
  final String name;
  final String deviceName;

  late DecardDB decardDB;
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

  DataLoader cardFileLoader;

  Child(this.name, this.deviceName, this.appDir, this.cardFileLoader);

  Future<void> init() async {
    rootDir = join(appDir, '$name$namesSeparator$deviceName');

    final dbDir = await Directory( join(rootDir, 'db') ).create(recursive : true);

    downloadDir = (await Directory( join(rootDir, 'download') ).create()).path;
    cardsDir    = (await Directory( join(rootDir, 'cards') ).create()).path;

    decardDB = DecardDB(dbDir.path);
    await decardDB.init();

    db = decardDB.database;
    dbSource = decardDB.source;

    regulatorPath = join(rootDir, regulatorFileName );
    _regulator = await Regulator.fromFile( regulatorPath );

    processCardController = ProcessCardController(db, regulator, dbSource.tabCardStat, dbSource.tabCardHead);
    await processCardController.init();

    cardController = CardController(
      dbSource             : dbSource,
      processCardController: processCardController,
      regulator            : regulator,
    );

  }

  Future<void> refreshRegulator() async {
    _regulator = await Regulator.fromFile( regulatorPath );
    _regulator!.applySetListToDB(dbSource);
  }

  Future<void> refreshCardsDB([List<String>? dirForScanList]) async {
    dirForScanList ??= [downloadDir];
    await cardFileLoader.refreshDB(dirForScanList: dirForScanList, selfDir: cardsDir, dbSource: dbSource);
  }

  static ChildAndDeviceNames getNamesFromDir(String dirName){
    final sub = dirName.split(namesSeparator);
    return ChildAndDeviceNames(sub.first, sub.last);
  }
}