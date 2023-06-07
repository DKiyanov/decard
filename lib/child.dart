import 'dart:io';

import 'package:decard/regulator.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'card_controller.dart';
import 'db.dart';

class Child {
  final String appDir;
  final String name;

  late DecardDB decardDB;
  late Database db;
  late DbSource dbSource;

  late ProcessCardController processCardController;
  late CardController cardController;

  late Regulator regulator;
  late String _regulatorPath;

  late String downloadDir;
  late String cardsDir;

  Child(this.name, this.appDir);

  Future<void> init() async {
    final dbDir = await Directory( join(appDir, name, 'db') ).create(recursive : true);

    downloadDir = (await Directory( join(appDir, name, 'download') ).create()).path;
    cardsDir    = (await Directory( join(appDir, name, 'cards') ).create()).path;

    decardDB = DecardDB(dbDir.path);
    await decardDB.init();

    db = decardDB.database;
    dbSource = decardDB.source;

    _regulatorPath = join(appDir, name, 'regulator.json' );
    regulator = await Regulator.fromFile( _regulatorPath );

    processCardController = ProcessCardController(db, regulator, dbSource.tabCardStat, dbSource.tabCardHead);
    await processCardController.init();

    cardController = CardController(
      dbSource             : dbSource,
      processCardController: processCardController,
    );
  }
}