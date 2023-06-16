import 'dart:io';

import 'package:decard/regulator.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'card_controller.dart';
import 'db.dart';

class ChildAndDeviceNames {
  final String childName;
  final String deviceName;
  ChildAndDeviceNames(this.childName, this.deviceName);
}

class Child {
  static String namesSeparator = '@';
  final String appDir;
  final String name;
  final String deviceName;

  late DecardDB decardDB;
  late Database db;
  late DbSource dbSource;

  late ProcessCardController processCardController;
  late CardController cardController;

  late Regulator regulator;
  late String _regulatorPath;

  late String rootDir;
  late String downloadDir;
  late String cardsDir;

  Child(this.name, this.deviceName, this.appDir);

  Future<void> init() async {
    rootDir = '$name$namesSeparator$deviceName';
    final dbDir = await Directory( join(appDir, rootDir, 'db') ).create(recursive : true);

    downloadDir = (await Directory( join(appDir, rootDir, 'download') ).create()).path;
    cardsDir    = (await Directory( join(appDir, rootDir, 'cards') ).create()).path;

    decardDB = DecardDB(dbDir.path);
    await decardDB.init();

    db = decardDB.database;
    dbSource = decardDB.source;

    _regulatorPath = join(appDir, rootDir, 'regulator.json' );
    regulator = await Regulator.fromFile( _regulatorPath );

    processCardController = ProcessCardController(db, regulator, dbSource.tabCardStat, dbSource.tabCardHead);
    await processCardController.init();

    cardController = CardController(
      dbSource             : dbSource,
      processCardController: processCardController,
      regulator            : regulator,
    );
  }

  static ChildAndDeviceNames getNamesFromDir(String dirName){
    final sub = dirName.split(namesSeparator);
    return ChildAndDeviceNames(sub.first, sub.last);
  }
}