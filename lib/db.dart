import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';


class DbSource {
  final Database db;
  late TabSourceFile   tabSourceFile;
  late TabJsonFile     tabJsonFile;
  late TabCardHead     tabCardHead;
  late TabCardTag      tabCardTag;
  late TabCardLink     tabCardLink;
  late TabCardLinkTag  tabCardLinkTag;
  late TabCardBody     tabCardBody;
  late TabCardStyle    tabCardStyle;
  late TabQualityLevel tabQualityLevel;
  late TabCardStat     tabCardStat;

  DbSource(this.db){
    tabSourceFile   = TabSourceFile(db);
    tabJsonFile     = TabJsonFile(db);
    tabCardHead     = TabCardHead(db);
    tabCardTag      = TabCardTag(db);
    tabCardLink     = TabCardLink(db);
    tabCardLinkTag  = TabCardLinkTag(db);
    tabCardBody     = TabCardBody(db);
    tabCardStyle    = TabCardStyle(db);
    tabQualityLevel = TabQualityLevel(db);
    tabCardStat     = TabCardStat(db);
  }
}

/// исходные файлы
class TabSourceFile {
  static const String tabName         = 'SourceFile';

  static const String kSourceFileID   = 'SourceFileID';
  static const String kFilePath       = 'filePath';
  static const String kChangeDateTime = 'changeDateTime';
  static const String kSize           = 'size';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kSourceFileID   INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kFilePath       TEXT,"
      "$kChangeDateTime INTEGER,"
      "$kSize           INTEGER"
      ")";

  final Database db;

  TabSourceFile(this.db);

  Future<bool> checkFileRegistered(File file) async {
    return checkFileRegisteredEx(file.path, await file.lastModified(), await file.length());
  }

  Future<bool> checkFileRegisteredEx(String path, DateTime changeDateTime, int size) async {
    List<Map> maps = await db.query(tabName,
        columns   : [kSourceFileID],
        where     : '$kFilePath = ? and $kChangeDateTime = ? and $kSize = ?',
        whereArgs : [path, changeDateTime.millisecondsSinceEpoch, size]);

    return maps.isNotEmpty;
  }

  Future<int> registerFile(File file) async {
    return registerFileEx(file.path, await file.lastModified(), await file.length());
  }

  Future<int> registerFileEx(String path, DateTime changeDateTime, int size) async {
    final fileID = await db.insert(tabName, {
      kFilePath       : path,
      kChangeDateTime : changeDateTime.millisecondsSinceEpoch,
      kSize           : size
    });
    return fileID;
  }

}

/// загруженные json файлы
class TabJsonFile {
  static const String tabName       = 'JsonFile';

  static const String kJsonFileID   = 'jsonFileID';
  static const String kSourceFileID = 'sourceFileID';
  static const String kPath         = 'path';
  static const String kFilename     = 'filename';
  static const String kTitle        = 'title';
  static const String kGuid         = 'GUID';
  static const String kVersion      = 'version';
  static const String kAuthor       = 'author';
  static const String kSite         = 'site';
  static const String kEmail        = 'email';
  static const String kLicense      = 'license';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kJsonFileID   INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kSourceFileID INTEGER,"
      "$kPath         TEXT,"
      "$kFilename     TEXT,"
      "$kTitle        TEXT,"
      "$kGuid         TEXT,"
      "$kVersion      INTEGER,"
      "$kAuthor       TEXT,"
      "$kSite         TEXT,"
      "$kEmail        TEXT,"
      "$kLicense      TEXT"
      ")";

  final Database db;
  TabJsonFile(this.db);

  final Map<String, Object?> _row = {};

  int     get jsonFileID   => _row[kJsonFileID   ] as int;
  int     get sourceFileID => _row[kSourceFileID ] as int;
  String  get path         => _row[kPath         ] as String;
  String  get filename     => _row[kFilename     ] as String;
  String  get title        => _row[kTitle        ] as String;
  String  get guid         => _row[kGuid         ] as String;
  int     get version      => _row[kVersion      ] as int;
  String? get author       => _row[kAuthor       ] as String?;
  String? get site         => _row[kSite         ] as String?;
  String? get email        => _row[kEmail        ] as String?;
  String? get license      => _row[kLicense      ] as String?;

  /// возвращает запись файла к указанному guid
  Future<bool> getRowByGuid(String guid) async {
    final List<Map<String, Object?>> rows = await db.query(tabName,
      where     : '$kGuid = ?',
      whereArgs : [guid]
    );

    if (rows.isEmpty) {
      _row.clear();
      return false;
    }

    _row.clear();
    _row.addAll(rows.first);
    return true;
  }

  setRow(int sourceFileID, String path, String filename, Map jsonMap){
    _row[kSourceFileID] = sourceFileID;
    _row[kPath        ] = path;
    _row[kFilename    ] = filename;
    _row[kTitle       ] = jsonMap[kTitle   ];
    _row[kGuid        ] = jsonMap[kGuid    ];
    _row[kVersion     ] = jsonMap[kVersion ];
    _row[kAuthor      ] = jsonMap[kAuthor  ];
    _row[kSite        ] = jsonMap[kSite    ];
    _row[kEmail       ] = jsonMap[kEmail   ];
    _row[kLicense     ] = jsonMap[kLicense ];
  }

  Future<void> save() async {
    if (_row[kJsonFileID] == null){
      _row[kJsonFileID] = await db.insert(tabName, _row);
    } else {
      final jsonFileID = _row[kJsonFileID ] as int;
      final updateRow = Map<String, dynamic>.from(_row);
      updateRow.remove(kJsonFileID);
      await db.update(tabName, updateRow,
        where: '$kJsonFileID = ?',
        whereArgs: [jsonFileID]
      );
    }
  }

  Future<Map<String, dynamic>?> getRow({ required int jsonFileID}) async {
    final rows = await db.query(tabName,
        where     : '$kJsonFileID = ?',
        whereArgs : [jsonFileID]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];
    return row;
  }

  Future<List<Map<String, Object?>>> getAllRows() async {
    final rows = await db.query(tabName);
    return rows;
  }
}

class TabCardStyle {
  static const String tabName        = 'CardStyle';

  static const String kID            = 'id';
  static const String kJsonFileID    = TabJsonFile.kJsonFileID;
  static const String kCardStyleKey  = 'cardStyleKey';
  static const String kJson          = 'json';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID           INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID   INTEGER,"
      "$kCardStyleKey TEXT,"
      "$kJson         TEXT" // данные стиля хранятся как json, когда понадобится распаковываются
      ")";

  final Database db;
  TabCardStyle(this.db);

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }

  Future<void> insertRow({ required int jsonFileID, required String cardStyleKey, required String jsonStr }) async {
    final Map<String, Object?> row = {
      kJsonFileID   : jsonFileID,
      kCardStyleKey : cardStyleKey,
      kJson         : jsonStr
    };

    await db.insert(tabName, row);
  }

  Future<Map<String, dynamic>?> getRow({ required int jsonFileID, required String cardStyleKey }) async {
    final rows = await db.query(tabName,
        where     : '$kJsonFileID = ? and $kCardStyleKey = ?',
        whereArgs : [jsonFileID, cardStyleKey]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];

    final String jsonStr = (row[kJson]) as String;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

    jsonMap.addEntries(row.entries.where((element) => element.key != kJson));

    return jsonMap;
  }
}

class TabQualityLevel {
  static const String tabName        = 'QualityLevel';

  static const String kID            = 'id';
  static const String kJsonFileID    = TabJsonFile.kJsonFileID;
  static const String kQualityName   = 'qualityName';
  static const String kMinQuality    = 'minQuality';
  static const String kAvgQuality    = 'avgQuality';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID           INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID   INTEGER,"
      "$kQualityName  TEXT,"
      "$kMinQuality   INTEGER,"
      "$kAvgQuality   INTEGER"
      ")";

  final Database db;
  TabQualityLevel(this.db);

  Future<void> insertRow({ required int jsonFileID, required String qualityName, required int minQuality, required int avgQuality }) async {
    final Map<String, Object?> row = {
      kJsonFileID   : jsonFileID,
      kQualityName  : qualityName,
      kMinQuality   : minQuality,
      kAvgQuality   : avgQuality,
    };

    await db.insert(tabName, row);
  }

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }
}

class TabCardHead {
  static const String tabName        = 'CardHead';

  static const String kCardID        = 'cardID';
  static const String kJsonFileID    = TabJsonFile.kJsonFileID;
  static const String kCardKey       = 'cardKey';
  static const String kTitle         = 'title';
  static const String kGroup      = 'groupKey'; // группировка карточек
  static const String kBodyCount     = 'bodyCount';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kCardID      INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID  INTEGER,"
      "$kCardKey     TEXT,"  // идентификатор карточки из json файла
      "$kTitle       TEXT,"
      "$kGroup    TEXT,"
      "$kBodyCount   INTEGER"
      ")";

  final Database db;
  TabCardHead(this.db);

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }

  Future<int> insertRow({
    required int jsonFileID,
    required String cardKey,
    required String title,
    required String cardGroupKey,
    required int bodyCount,
  }) async {
    final Map<String, Object?> row = {
      kJsonFileID : jsonFileID,
      kCardKey    : cardKey,
      kTitle      : title,
      kGroup   : cardGroupKey,
      kBodyCount  : bodyCount,
    };

    final id = await db.insert(tabName, row);
    return id;
  }

  Future<Map<String, dynamic>?> getRow(int cardID) async {
    final rows = await db.query(tabName,
        where     : '$kCardID = ?',
        whereArgs : [cardID]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];

    final Map<String, dynamic> jsonMap = {};

    row.forEach((key, value) {
      jsonMap[key] = value;
    });

    return jsonMap;
  }

  Future<int> getGroupCardCount({ required int jsonFileID, required cardGroupKey}) async {
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tabName WHERE $kJsonFileID = ? AND $kGroup = ?', [jsonFileID, cardGroupKey]))??0;
  }

  Future<List<Map<String, Object?>>> getAllRows() async {
    final rows = await db.query(tabName);
    return rows;
  }
}

class TabCardTag {
  static const String tabName         = 'CardTag';

  static const String kID             = 'id';
  static const String kJsonFileID     = TabJsonFile.kJsonFileID;
  static const String kCardID         = TabCardHead.kCardID;
  static const String kTag            = 'tag';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID             INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID     INTEGER,"
      "$kCardID         INTEGER,"
      "$kTag            TEXT"
      ")";

  final Database db;
  TabCardTag(this.db);

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }

  Future<void> insertRow({ required int jsonFileID, required int cardID, required String tag}) async {
    final Map<String, Object?> row = {
      kJsonFileID     : jsonFileID,
      kCardID         : cardID,
      kTag            : tag
    };

    await db.insert(tabName, row);
  }

  Future<List<String>> getCardTags({required int jsonFileID, required int cardID}) async {
    final rows = await db.query(tabName,
        columns   : [kTag],
        where     : '$kJsonFileID = ? and $kCardID = ?',
        whereArgs : [jsonFileID, cardID]
    );

    return rows.map((row) => row.values.first as String).toList();
  }
}
class TabCardLink {
  static const String tabName         = 'CardLink';

  static const String kLinkID         = 'linkID';
  static const String kJsonFileID     = TabJsonFile.kJsonFileID;
  static const String kCardID         = TabCardHead.kCardID;
  static const String kQualityName    = 'qualityName';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kLinkID         INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID     INTEGER,"
      "$kCardID         INTEGER,"
      "$kQualityName    TEXT"
      ")";

  final Database db;
  TabCardLink(this.db);

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }

  Future<int> insertRow({ required int jsonFileID, required int cardID, required String qualityName}) async {
    final Map<String, Object?> row = {
      kJsonFileID     : jsonFileID,
      kCardID         : cardID,
      kQualityName    : qualityName,
    };

    final ret = await db.insert(tabName, row);
    return ret;
  }
}

class TabCardLinkTag {
  static const String tabName  = 'CardLinkTag';

  static const String kID         = 'id';
  static const String kJsonFileID = TabJsonFile.kJsonFileID;
  static const String kLinkID     = TabCardLink.kLinkID;
  static const String kTag        = 'tag';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID          INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID  INTEGER,"
      "$kLinkID      INTEGER,"
      "$kTag         TEXT"
      ")";

  final Database db;
  TabCardLinkTag(this.db);

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }

  Future<void> insertRow({ required int jsonFileID, required int linkId, required String tag}) async {
    final Map<String, Object?> row = {
      kJsonFileID : jsonFileID,
      kLinkID     : linkId,
      kTag        : tag
    };

    await db.insert(tabName, row);
  }
}

class TabCardBody{
  static const String tabName     = 'CardBody';

  static const String kID         = 'id';
  static const String kJsonFileID = TabJsonFile.kJsonFileID;
  static const String kCardID     = TabCardHead.kCardID;
  static const String kBodyNum    = 'bodyNum';
  static const String kJson       = 'json';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID         INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID INTEGER,"
      "$kCardID     INTEGER," // идентификатор карточки из json файла
      "$kBodyNum    INTEGER," // у карточки может быть много тел, здесь хранится номер тела
      "$kJson       TEXT"     // данные тела карточки хранятся как json, когда понадобится распаковываются
      ")";

  final Database db;
  TabCardBody(this.db);

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }

  Future<void> insertRow({ required int jsonFileID, required int cardID, required int bodyNum, required String json }) async {
    final Map<String, Object?> row = {
      kJsonFileID : jsonFileID,
      kCardID     : cardID,
      kBodyNum    : bodyNum,
      kJson       : json
    };

    await db.insert(tabName, row);
  }

  Future<Map<String, dynamic>?> getRow({ required int jsonFileID, required int cardID, required int bodyNum }) async {
    final rows = await db.query(tabName,
        where     : '$kJsonFileID = ? and $kCardID = ? and $kBodyNum = ?',
        whereArgs : [jsonFileID, cardID, bodyNum]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];

    final String jsonStr = (row[kJson]) as String;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

    row.forEach((key, value) {
      jsonMap[key] = value;
    });

    return jsonMap;
  }
}

class DayResult {
  DayResult({
    required this.day,
    this.countTotal = 0,
    this.countOk    = 0
  });

  final int day;
  int countTotal;
  int countOk;

  void addResult(bool resultOk){
    countTotal ++;
    if (resultOk) countOk ++;
  }

  factory DayResult.fromJson(Map<String, dynamic> json) => DayResult(
    day        : json["day"],
    countTotal : json["countTotal"],
    countOk    : json["countOk"],
  );

  Map<String, dynamic> toJson() => {
    "day"        : day,
    "countTotal" : countTotal,
    "countOk"    : countOk,
  };
}


class TabCardStat {
  static const String tabName          = 'CardStat';

  static const String kID              = 'id';
  static const String kJsonFileID      = TabJsonFile.kJsonFileID;
  static const String kCardID          = TabCardHead.kCardID;
  static const String kCardKey         = 'cardKey';
  static const String kCardGroupKey    = 'cardGroupKey';
  static const String kQuality         = 'quality';
  static const String kQualityFromDate = 'qualityFromDate';
  static const String kStartDate       = 'startDate';
  static const String kLastTestDate    = 'lastTestDate';
  static const String kTestsCount      = 'testsCount';
  static const String kJson            = 'json';

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID              INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID      INTEGER,"
      "$kCardID          INTEGER,"
      "$kCardKey         TEXT,"    // идентификатор карточки из json файла
      "$kCardGroupKey    TEXT,"    // Группировка карточек
      "$kQuality         INTEGER," // качество изучения, 1 - картичка полностью изучена; 100 - минимальная степень изученности.
      "$kQualityFromDate INTEGER," // первая дата учтённая при расчёте quality
      "$kStartDate       INTEGER," // дата начала изучения
      "$kLastTestDate    INTEGER," // дата последнего изучения
      "$kTestsCount      INTEGER," // количество предъявления
      "$kJson            TEXT"     // данные статистики карточки хранятся как json, когда понадобится распаковываются используются для расчёта quality и обновляются
      ")";

  final Database db;
  TabCardStat(this.db);

  /// удаляет карточки которых нет в списке
  Future<void> removeOldCard(int jsonFileID, List<String> cardKeyList) async {
    final rows = await db.query(tabName,
      columns   : [kCardKey],
      where     : '$kJsonFileID = ?',
      whereArgs : [jsonFileID]
    );

    for (var row in rows) {
      final String cardKey = row[kCardKey] as String;
      if (!cardKeyList.contains(cardKey)){
        db.delete(tabName,
          where     : '$kJsonFileID = ? and $kCardKey = ?',
          whereArgs : [jsonFileID, cardKey]
        );
      }
    }
  }

  List<DayResult> dayResultsFromJson( String jsonStr){
    if (jsonStr.isEmpty){
      return [];
    }

    final jsonMap = jsonDecode(jsonStr);
    return List<DayResult>.from(jsonMap.map((x) => DayResult.fromJson(x)));
  }

  static String dayResultsToJson(List<DayResult> dayResults) {
    final jsonMap = List<dynamic>.from(dayResults.map((x) => x.toJson()));
    return jsonEncode(jsonMap);
  }

  Future<Map<String, dynamic>?> getRow(int cardID) async {
    final rows = await db.query(tabName,
        where     : '$kCardID = ?',
        whereArgs : [cardID]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];
    return row;
  }

  Future<int> insertRow({
    required int    jsonFileID,
    required int    cardID,
    required String cardKey,
    required String cardGroupKey,
    required int    quality,
    required int    date,
  }) async {
    Map<String, Object> row = {
      kJsonFileID      : jsonFileID,
      kCardID          : cardID,
      kCardKey         : cardKey,
      kCardGroupKey    : cardGroupKey,
      kQuality         : quality,
      kQualityFromDate : date,
      kStartDate       : date,
      kTestsCount      : 0,
      kJson            : '',
    };

    final id = await db.insert(TabCardStat.tabName, row);
    return id;
  }

  /// Удаляет все записи в таблице, нужно для тестовых нужд
  Future<void> clear() async {
    db.delete(tabName);
  }
}

class DBProvider {
  DBProvider._();

  static final DBProvider db = DBProvider._();

  Database? _database;

  Future<Database?> get database async {
    if (_database != null) return _database;
    _database = await _initDB();
    return _database;
  }

   Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "decard.db");
    print('DB path: $path');
    return await openDatabase(path, version: 1, onOpen: (db) {},
        onCreate: (Database db, int version) async {
          await _createTables(db);
        });
  }

  _createTables(Database db) async {
    await db.execute(TabSourceFile.createQuery);
    await db.execute(TabJsonFile.createQuery);
    await db.execute(TabCardStyle.createQuery);
    await db.execute(TabQualityLevel.createQuery);
    await db.execute(TabCardHead.createQuery);
    await db.execute(TabCardTag.createQuery);
    await db.execute(TabCardLink .createQuery);
    await db.execute(TabCardLinkTag .createQuery);
    await db.execute(TabCardBody.createQuery);
    await db.execute(TabCardStat.createQuery);
  }

  deleteDB( ) async {
    if (_database == null) return;
    deleteDatabase(_database!.path);
  }
}