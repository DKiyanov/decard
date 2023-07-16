import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:decard/regulator.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'decardj.dart';

/// Source files
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

  Future<Map<String, dynamic>?> getRow({ required int sourceFileID}) async {
    final rows = await db.query(tabName,
        where     : '$kSourceFileID = ?',
        whereArgs : [sourceFileID]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];
    return row;
  }

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.rawDelete(
      '''DELETE FROM $tabName WHERE $kSourceFileID IN (
       SELECT ${TabJsonFile.kSourceFileID}
         FROM ${TabJsonFile.tabName}
        WHERE ${TabJsonFile.kJsonFileID} = ?) 
      ''',
      [jsonFileID]
    );
  }
}

/// Loaded json files
class TabJsonFile {
  static const String tabName       = 'JsonFile';

  static const String kJsonFileID   = 'jsonFileID';
  static const String kSourceFileID = 'sourceFileID';
  static const String kPath         = 'path';
  static const String kFilename     = 'filename';
  static const String kTitle        = DjfFile.title;
  static const String kGuid         = DjfFile.guid;
  static const String kVersion      = DjfFile.version;
  static const String kAuthor       = DjfFile.author;
  static const String kSite         = DjfFile.site;
  static const String kEmail        = DjfFile.email;
  static const String kLicense      = DjfFile.license;

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

  final Map<int, String> _jsonFileIdToGuidMap = {};

  String jsonFileIdToFileGuid(int jsonFileId) => _jsonFileIdToGuidMap[jsonFileId]!;

  int? fileGuidToJsonFileId(String guid) {
    for (var element in _jsonFileIdToGuidMap.entries) {
      if (element.value == guid) return element.key;
    }

    return null;
  }

  Future<void> init() async {
    final rows = await db.query(tabName, columns: [kJsonFileID, kGuid]);

    for (var row in rows) {
      final jsonFileID = row[kJsonFileID] as int;
      final fileGuid   = row[kGuid] as String;
      _jsonFileIdToGuidMap[jsonFileID] = fileGuid;
    }
  }

  /// returns the file record to the specified guid
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

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }
}

class TabCardStyle {
  static const String tabName        = 'CardStyle';

  static const String kID            = 'id';
  static const String kJsonFileID    = TabJsonFile.kJsonFileID;
  static const String kCardStyleKey  = 'cardStyleKey';  // map from DjfCardStyle.id
  static const String kJson          = 'json';          // style data are stored as json, when needed they are unpacked

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID           INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID   INTEGER,"
      "$kCardStyleKey TEXT,"
      "$kJson         TEXT" 
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
  static const String kQualityName   = 'qualityName'; // map from DjfQualityLevel.qualityName
  static const String kMinQuality    = DjfQualityLevel.minQuality;
  static const String kAvgQuality    = DjfQualityLevel.avgQuality;

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
  static const String kCardKey       = 'cardKey'; // map from DjfCard.id
  static const String kTitle         = DjfCard.title;
  static const String kDifficulty    = DjfCard.difficulty;
  static const String kGroup         = 'groupKey'; // map from DjfCard.group;
  static const String kBodyCount     = 'bodyCount'; // number of records in the DjfCard.bodyList

  static const String kExclude       = DrfCardSet.exclude; // Exclusion of a card from study, set through the regulator filter
  static const String kRegulatorSetIndex   = 'regulatorSetIndex'; // index of set in Regulator.setList

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kCardID        INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID    INTEGER,"
      "$kCardKey       TEXT,"  // Card identifier from a json file
      "$kTitle         TEXT,"
      "$kDifficulty    INTEGER,"
      "$kGroup         TEXT,"
      "$kBodyCount     INTEGER,"
      "$kExclude       INTEGER,"
      "$kRegulatorSetIndex INTEGER"
      ")";

  final Database db;
  TabCardHead(this.db);

  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(tabName, where: '$kJsonFileID = ?', whereArgs: [jsonFileID]);
  }

  Future<int> insertRow({
    required int    jsonFileID,
    required String cardKey,
    required String title,
    required int    difficulty,
    required String cardGroupKey,
    required int    bodyCount,
  }) async {
    final Map<String, Object?> row = {
      kJsonFileID : jsonFileID,
      kCardKey    : cardKey,
      kTitle      : title,
      kDifficulty : difficulty,
      kGroup      : cardGroupKey,
      kBodyCount  : bodyCount,
      kExclude    : 0,
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

  Future<void> clearRegulatorPatchOnAllRow() async {
    final Map<String, dynamic> updateRow = {
      kRegulatorSetIndex : null,
      kExclude           : 0,
    };
    await db.update(tabName, updateRow);
  }

  Future<void> setRegulatorPatchOnCard({required int cardID, required int regulatorSetIndex, required bool exclude}) async {
    final Map<String, dynamic> updateRow = {
      kRegulatorSetIndex : regulatorSetIndex,
      kExclude           : exclude,
    };

    await db.update(tabName, updateRow, where: '$kCardID = ?', whereArgs: [cardID]);
  }

  Future<List<String>> getFileCardKeyList({ required int jsonFileID }) async {
    final rows = await db.query(tabName, distinct: true,
      columns   : [kCardKey],
      where     : '$kJsonFileID = ?',
      whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
  }

  Future<List<String>> getFileGroupList({ required int jsonFileID }) async {
    final rows = await db.query(tabName, distinct: true,
        columns   : [kGroup],
        where     : '$kJsonFileID = ?',
        whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
  }

  Future<int> getCardIdFromKey(int jsonFileID, String cardKey) async {
    final rows = await db.query(tabName, distinct: true,
        columns   : [kCardID],
        where     : '$kJsonFileID = ? AND $kCardKey = ?',
        whereArgs : [jsonFileID, cardKey]
    );

    final cardID = rows.first.values.first as int;

    return cardID;
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

  Future<List<String>> getFileTagList({ required int jsonFileID }) async {
    final rows = await db.query(tabName, distinct: true,
        columns   : [kTag],
        where     : '$kJsonFileID = ?',
        whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
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
  static const String kBodyNum    = 'bodyNum'; // the card can have many bodies, the body number is stored here
  static const String kJson       = 'json';    // card body data are stored as json, when needed they are unpacked

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID         INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID INTEGER,"
      "$kCardID     INTEGER," 
      "$kBodyNum    INTEGER," 
      "$kJson       TEXT"     
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
  static const String kCardKey         = 'cardKey';         // Card identifier from a json file
  static const String kCardGroupKey    = 'cardGroupKey';    // Card group from a json file
  static const String kQuality         = 'quality';         // quality of study, 100 - the card is completely studied; 0 - minimal degree of study.
  static const String kQualityFromDate = 'qualityFromDate'; // the first date taken into account when calculating quality
  static const String kStartDate       = 'startDate';       // starting date of study
  static const String kLastTestDate    = 'lastTestDate';
  static const String kLastResult      = 'lastResult';      // boolean
  static const String kTestsCount      = 'testsCount';
  static const String kJson            = 'json';            // card statistics data are stored as json, when needed they are unpacked and used to calculate quality and updated

  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID              INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kJsonFileID      INTEGER,"
      "$kCardID          INTEGER,"
      "$kCardKey         TEXT,"    
      "$kCardGroupKey    TEXT,"    
      "$kQuality         INTEGER," 
      "$kQualityFromDate INTEGER," 
      "$kStartDate       INTEGER," 
      "$kLastTestDate    INTEGER," 
      "$kLastResult      INTEGER," 
      "$kTestsCount      INTEGER," 
      "$kJson            TEXT"     
      ")";

  final Database db;
  TabCardStat(this.db);

  /// removes cards that are not on the list
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
  }) async {
    Map<String, Object> row = {
      kJsonFileID      : jsonFileID,
      kCardID          : cardID,
      kCardKey         : cardKey,
      kCardGroupKey    : cardGroupKey,
      kQuality         : 0,
      kLastResult      : false,
      kQualityFromDate : 0,
      kStartDate       : 0,
      kTestsCount      : 0,
      kJson            : '',
    };

    final id = await db.insert(tabName, row);
    return id;
  }

  /// Deletes all records in the table, needed for test purposes
  Future<void> clear() async {
    db.delete(tabName);
  }

  Future<List<Map<String, Object?>>> getAllRows() async {
    final rows = await db.query(tabName);
    return rows;
  }
}

/// For card result log
class TestResult {
  final String fileGuid;
  final int    fileVersion;
  final String cardID;  // == json Card.id
  final int    bodyNum;
  final bool   result;
  final double earned;
  final int    dateTime;
  final int    qualityBefore;
  final int    qualityAfter;
  final int    difficulty;

  TestResult({
    required this.fileGuid,
    required this.fileVersion,
    required this.cardID,
    required this.bodyNum,
    required this.result,
    required this.earned,
    required this.dateTime,
    required this.qualityBefore,
    required this.qualityAfter,
    required this.difficulty,
  });

  factory TestResult.fromMap(Map<String, dynamic> json) {
    final mapResult = json[TabTestResult.kResult] ?? false;
    bool result;

    if (mapResult is int ) {
      result = mapResult == 1;
    } else {
      result = mapResult;
    }

    return TestResult(
      fileGuid      : json[TabTestResult.kFileGuid     ],
      fileVersion   : json[TabTestResult.kFileVersion  ],
      cardID        : json[TabTestResult.kCardID       ],
      bodyNum       : json[TabTestResult.kBodyNum      ],
      result        : result,
      earned        : json[TabTestResult.kEarned       ],
      dateTime      : json[TabTestResult.kDateTime     ],
      qualityBefore : json[TabTestResult.kQualityBefore],
      qualityAfter  : json[TabTestResult.kQualityAfter ],
      difficulty    : json[TabTestResult.kDifficulty   ],
    );
  }

  Map<String, dynamic> toJson() => {
    TabTestResult.kFileGuid      : fileGuid,
    TabTestResult.kFileVersion   : fileVersion,
    TabTestResult.kCardID        : cardID,
    TabTestResult.kBodyNum       : bodyNum,
    TabTestResult.kResult        : result,
    TabTestResult.kEarned        : earned,
    TabTestResult.kDateTime      : dateTime,
    TabTestResult.kQualityBefore : qualityBefore,
    TabTestResult.kQualityAfter  : qualityAfter,
    TabTestResult.kDifficulty    : difficulty,
  };
}

class TabTestResult {
  static const String tabName = 'TestResult';

  static const String kID            = 'id';
  static const String kFileGuid      = "fileGuid";
  static const String kFileVersion   = "fileVersion";
  static const String kCardID        = "cardID";
  static const String kBodyNum       = "bodyNum";
  static const String kResult        = "result";
  static const String kEarned        = "earned";
  static const String kDateTime      = "dateTime";
  static const String kQualityBefore = "qualityBefore";
  static const String kQualityAfter  = "qualityAfter";
  static const String kDifficulty    = "difficulty";


  static const String createQuery = "CREATE TABLE $tabName ("
      "$kID            INTEGER PRIMARY KEY AUTOINCREMENT,"
      "$kFileGuid      TEXT,"
      "$kFileVersion   INTEGER,"
      "$kCardID        TEXT,"
      "$kBodyNum       INTEGER,"
      "$kResult        INTEGER,"
      "$kEarned        INTEGER,"
      "$kDateTime      INTEGER,"
      "$kQualityBefore INTEGER,"
      "$kQualityAfter  INTEGER,"
      "$kDifficulty    INTEGER"
      ")";

  final Database db;

  TabTestResult(this.db);

  Future<int> insertRow(TestResult testResult) async {
    Map<String, Object> row = {
      kFileGuid      : testResult.fileGuid,
      kFileVersion   : testResult.fileVersion,
      kCardID        : testResult.cardID,
      kBodyNum       : testResult.bodyNum,
      kResult        : testResult.result,
      kEarned        : testResult.earned,
      kDateTime      : testResult.dateTime,
      kQualityBefore : testResult.qualityBefore,
      kQualityAfter  : testResult.qualityAfter,
      kDifficulty    : testResult.difficulty,
    };

    final id = await db.insert(tabName, row);
    return id;
  }

  Future<List<TestResult>> getForPeriod(int fromDate, int toDate) async {
    final resultList = <TestResult>[];

    final rows = await db.query(tabName,
        where     : '$kDateTime >= ? and $kDateTime <= ?',
        whereArgs : [fromDate, toDate]
    );

    for (var row in rows) {
      resultList.add(TestResult.fromMap(row));
    }

    return resultList;
  }

  Future<int> getFirstTime() async {
    final rows = await db.rawQuery('SELECT MIN($kDateTime) as dateTime FROM $tabName');
    if (rows.isEmpty) return 0;
    return (rows.first.values.first??0) as int;
  }

  Future<int> getLastTime() async {
    final rows = await db.rawQuery('SELECT MAX($kDateTime) as dateTime FROM $tabName');
    if (rows.isEmpty) return 0;
    return (rows.first.values.first??0) as int;
  }
}

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
  late TabTestResult   tabTestResult;

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
    tabTestResult   = TabTestResult(db);
  }

  Future<void> init() async {
    await tabJsonFile.init();
  }

   Future<void> deleteJsonFile(int jsonFileID) async {
     await tabSourceFile.deleteJsonFile(jsonFileID);
     await tabJsonFile.deleteJsonFile(jsonFileID);
     await tabCardHead.deleteJsonFile(jsonFileID);
     await tabCardTag.deleteJsonFile(jsonFileID);
     await tabCardLink.deleteJsonFile(jsonFileID);
     await tabCardLinkTag.deleteJsonFile(jsonFileID);
     await tabCardBody.deleteJsonFile(jsonFileID);
     await tabCardStyle.deleteJsonFile(jsonFileID);
     await tabQualityLevel.deleteJsonFile(jsonFileID);
   }
}

class DecardDB {
  final String dbPath;
  
  DecardDB(this.dbPath);

  late Database database;
  late DbSource source;

  Future<void> init() async {
    String path = join(dbPath, "decard.db");
    database = await openDatabase(path, version: 1, onOpen: (db) {},
      onCreate: (Database db, int version) async {
          await _createTables(db);
    });

    source = DbSource(database);
    await source.init();
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
    await db.execute(TabTestResult.createQuery);
  }

  deleteDB( ) async {
    deleteDatabase(database.path);
  }
}
