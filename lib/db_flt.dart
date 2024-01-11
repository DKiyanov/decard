import 'dart:convert';
import 'dart:core';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'db.dart';

class TabSourceFileFlt extends TabSourceFile {
  static const String createQuery = "CREATE TABLE ${TabSourceFile.tabName} ("
      "${TabSourceFile.kSourceFileID}   INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabSourceFile.kFilePath}       TEXT,"
      "${TabSourceFile.kChangeDateTime} INTEGER,"
      "${TabSourceFile.kSize}           INTEGER"
      ")";

  final Database db;

  TabSourceFileFlt(this.db);

  @override
  Future<bool> checkFileRegistered(String path, DateTime changeDateTime, int size) async {
    List<Map> maps = await db.query(TabSourceFile.tabName,
        columns   : [TabSourceFile.kSourceFileID],
        where     : '${TabSourceFile.kFilePath} = ? and ${TabSourceFile.kChangeDateTime} = ? and ${TabSourceFile.kSize} = ?',
        whereArgs : [path, changeDateTime.millisecondsSinceEpoch, size]);

    return maps.isNotEmpty;
  }

  @override
  Future<int> registerFile(String path, DateTime changeDateTime, int size) async {
    final fileID = await db.insert(TabSourceFile.tabName, {
      TabSourceFile.kFilePath       : path,
      TabSourceFile.kChangeDateTime : changeDateTime.millisecondsSinceEpoch,
      TabSourceFile.kSize           : size
    });
    return fileID;
  }

  @override
  Future<Map<String, dynamic>?> getRow({ required int sourceFileID}) async {
    final rows = await db.query(TabSourceFile.tabName,
        where     : '${TabSourceFile.kSourceFileID} = ?',
        whereArgs : [sourceFileID]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];
    return row;
  }
}


/// Loaded json files
class TabJsonFileFlt extends TabJsonFile {
  static const String createQuery = "CREATE TABLE ${TabJsonFile.tabName} ("
      "${TabJsonFile.kJsonFileID}   INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabJsonFile.kSourceFileID} INTEGER,"
      "${TabJsonFile.kRootPath}     TEXT,"
      "${TabJsonFile.kTitle}        TEXT,"
      "${TabJsonFile.kGuid}         TEXT,"
      "${TabJsonFile.kVersion}      INTEGER,"
      "${TabJsonFile.kAuthor}       TEXT,"
      "${TabJsonFile.kSite}         TEXT,"
      "${TabJsonFile.kEmail}        TEXT,"
      "${TabJsonFile.kLicense}      TEXT"
      ")";

  final Database db;
  TabJsonFileFlt(this.db);

  final Map<int, FileKey> _jsonFileIdToGuidMap = {};

  @override
  FileKey jsonFileIdToFileKey(int jsonFileId) {
    return _jsonFileIdToGuidMap[jsonFileId]!;
  }

  @override
  int? fileGuidToJsonFileId(String guid) {
    for (var element in _jsonFileIdToGuidMap.entries) {
      if (element.value.guid == guid) return element.key;
    }

    return null;
  }

  Future<void> init() async {
    _jsonFileIdToGuidMap.clear();

    final rows = await db.query(TabJsonFile.tabName, columns: [TabJsonFile.kJsonFileID, TabJsonFile.kGuid, TabJsonFile.kVersion]);

    for (var row in rows) {
      final jsonFileID = row[TabJsonFile.kJsonFileID] as int;
      final fileGuid   = row[TabJsonFile.kGuid] as String;
      final version    = row[TabJsonFile.kVersion] as int;
      _jsonFileIdToGuidMap[jsonFileID] = FileKey(fileGuid, version, jsonFileID);
    }
  }

  @override
  Future<List<Map<String, Object?>>> getRowByGuid(String guid, {int? version}) async {
    if (version == null) {
      final List<Map<String, Object?>> rows = await db.query(TabJsonFile.tabName,
          where     : '${TabJsonFile.kGuid} = ?',
          whereArgs : [guid]
      );

      return rows;
    }

    final List<Map<String, Object?>> rows = await db.query(TabJsonFile.tabName,
      where     : '${TabJsonFile.kGuid} = ? and ${TabJsonFile.kVersion} = ?',
      whereArgs : [guid, version]
    );

    return rows;
  }

  @override
  Future<Map<String, dynamic>?> getRowBySourceID({required String sourceFileID}) async {
    final List<Map<String, Object?>> rows = await db.query(TabJsonFile.tabName,
        where     : '${TabJsonFile.kSourceFileID} = ?',
        whereArgs : [sourceFileID]
    );

    if (rows.isEmpty) return null;

    return rows.first;
  }

  @override
  Future<Map<String, dynamic>?> getRow({ required int jsonFileID}) async {
    final rows = await db.query(TabJsonFile.tabName,
        where     : '${TabJsonFile.kJsonFileID} = ?',
        whereArgs : [jsonFileID]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];
    return row;
  }

  @override
  Future<List<Map<String, Object?>>> getAllRows() async {
    final rows = await db.query(TabJsonFile.tabName);
    return rows;
  }

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabJsonFile.tabName, where: '${TabJsonFile.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }


  @override
  Future<int> insertRow(String sourceFileID, String rootPath, Map jsonMap) async {
    final Map<String, Object?> row = {
      TabJsonFile.kSourceFileID : sourceFileID,
      TabJsonFile.kJsonFileID   : jsonMap[TabJsonFile.kJsonFileID  ],
      TabJsonFile.kRootPath     : jsonMap[TabJsonFile.kRootPath    ],
      TabJsonFile.kTitle        : jsonMap[TabJsonFile.kTitle       ],
      TabJsonFile.kGuid         : jsonMap[TabJsonFile.kGuid        ],
      TabJsonFile.kVersion      : jsonMap[TabJsonFile.kVersion     ],
      TabJsonFile.kAuthor       : jsonMap[TabJsonFile.kAuthor      ],
      TabJsonFile.kSite         : jsonMap[TabJsonFile.kSite        ],
      TabJsonFile.kEmail        : jsonMap[TabJsonFile.kEmail       ],
      TabJsonFile.kLicense      : jsonMap[TabJsonFile.kLicense     ],
    };

    final id = await db.insert(TabJsonFile.tabName, row);
    return id;
  }
}

class TabCardStyleFlt extends TabCardStyle{
  static const String createQuery = "CREATE TABLE ${TabCardStyle.tabName} ("
      "${TabCardStyle.kID}           INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabCardStyle.kJsonFileID}   INTEGER,"
      "${TabCardStyle.kCardStyleKey} TEXT,"
      "${TabCardStyle.kJson}         TEXT"
      ")";

  final Database db;
  TabCardStyleFlt(this.db);

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabCardStyle.tabName, where: '${TabCardStyle.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<void> insertRow({ required int jsonFileID, required String cardStyleKey, required String jsonStr }) async {
    final Map<String, Object?> row = {
      TabCardStyle.kJsonFileID   : jsonFileID,
      TabCardStyle.kCardStyleKey : cardStyleKey,
      TabCardStyle.kJson         : jsonStr
    };

    await db.insert(TabCardStyle.tabName, row);
  }

  @override
  Future<Map<String, dynamic>?> getRow({ required int jsonFileID, required String cardStyleKey }) async {
    final rows = await db.query(TabCardStyle.tabName,
        where     : '${TabCardStyle.kJsonFileID} = ? and ${TabCardStyle.kCardStyleKey} = ?',
        whereArgs : [jsonFileID, cardStyleKey]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];

    final String jsonStr = (row[TabCardStyle.kJson]) as String;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

    jsonMap.addEntries(row.entries.where((element) => element.key != TabCardStyle.kJson));

    return jsonMap;
  }

  @override
  Future<List<String>> getStyleKeyList({required int jsonFileID}) async {
    final rows = await db.query(TabCardStyle.tabName, distinct: true,
        columns   : [TabCardStyle.kCardStyleKey],
        where     : '${TabCardStyle.kJsonFileID} = ?',
        whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
  }
}

class TabQualityLevelFlt extends TabQualityLevel {
  static const String createQuery = "CREATE TABLE ${TabQualityLevel.tabName} ("
      "${TabQualityLevel.kID}           INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabQualityLevel.kJsonFileID}   INTEGER,"
      "${TabQualityLevel.kQualityName}  TEXT,"
      "${TabQualityLevel.kMinQuality}   INTEGER,"
      "${TabQualityLevel.kAvgQuality}   INTEGER"
      ")";

  final Database db;
  TabQualityLevelFlt(this.db);

  @override
  Future<void> insertRow({ required int jsonFileID, required String qualityName, required int minQuality, required int avgQuality }) async {
    final Map<String, Object?> row = {
      TabQualityLevel.kJsonFileID   : jsonFileID,
      TabQualityLevel.kQualityName  : qualityName,
      TabQualityLevel.kMinQuality   : minQuality,
      TabQualityLevel.kAvgQuality   : avgQuality,
    };

    await db.insert(TabQualityLevel.tabName, row);
  }

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabQualityLevel.tabName, where: '${TabQualityLevel.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<List<String>> getLevelNameList({required int jsonFileID}) async {
    final rows = await db.query(TabQualityLevel.tabName, distinct: true,
        columns   : [TabQualityLevel.kQualityName],
        where     : '${TabQualityLevel.kJsonFileID} = ?',
        whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
  }
}

class TabCardHeadFlt extends TabCardHead {
  static const String createQuery = "CREATE TABLE ${TabCardHead.tabName} ("
      "${TabCardHead.kCardID}        INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabCardHead.kJsonFileID}    INTEGER,"
      "${TabCardHead.kCardKey}       TEXT,"  // Card identifier from a json file
      "${TabCardHead.kTitle}         TEXT,"
      "${TabCardHead.kHelp}          TEXT,"
      "${TabCardHead.kDifficulty}    INTEGER,"
      "${TabCardHead.kGroup}         TEXT,"
      "${TabCardHead.kBodyCount}     INTEGER,"
      "${TabCardHead.kExclude}       INTEGER,"
      "${TabCardHead.kSourceRowId}   INTEGER,"
      "${TabCardHead.kRegulatorSetIndex} INTEGER"
      ")";

  final Database db;
  TabCardHeadFlt(this.db);

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabCardHead.tabName, where: '${TabCardHead.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<int> insertRow({
    required int    jsonFileID,
    required String cardKey,
    required String title,
    required String help,
    required int    difficulty,
    required String cardGroupKey,
    required int    bodyCount,
    int? sourceRowId,
  }) async {
    final Map<String, Object?> row = {
      TabCardHead.kJsonFileID : jsonFileID,
      TabCardHead.kCardKey    : cardKey,
      TabCardHead.kTitle      : title,
      TabCardHead.kHelp       : help,
      TabCardHead.kDifficulty : difficulty,
      TabCardHead.kGroup      : cardGroupKey,
      TabCardHead.kBodyCount  : bodyCount,
      TabCardHead.kExclude    : 0,
      TabCardHead.kSourceRowId: sourceRowId,
    };

    final id = await db.insert(TabCardHead.tabName, row);
    return id;
  }

  @override
  Future<Map<String, dynamic>?> getRow({required int jsonFileID, required int cardID}) async {
    final rows = await db.query(TabCardHead.tabName,
        where     : '${TabCardHead.kCardID} = ?',
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

  @override
  Future<int> getGroupCardCount({ required int jsonFileID, required cardGroupKey}) async {
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${TabCardHead.tabName} WHERE ${TabCardHead.kJsonFileID} = ? AND ${TabCardHead.kGroup} = ?',
        [jsonFileID, cardGroupKey]))??0;
  }

  @override
  Future<List<Map<String, Object?>>> getAllRows() async {
    final rows = await db.query(TabCardHead.tabName);
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> getFileRows({required int jsonFileID}) async {
    final rows = await db.query(TabCardHead.tabName, where : '${TabCardHead.kJsonFileID} = ?', whereArgs : [jsonFileID]);
    return rows;
  }

  @override
  Future<void> clearRegulatorPatchOnAllRow() async {
    final Map<String, dynamic> updateRow = {
      TabCardHead.kRegulatorSetIndex : null,
      TabCardHead.kExclude           : 0,
    };
    await db.update(TabCardHead.tabName, updateRow);
  }

  @override
  Future<void> setRegulatorPatchOnCard({required int jsonFileID, required int cardID, required int regulatorSetIndex, required bool exclude}) async {
    final Map<String, dynamic> updateRow = {
      TabCardHead.kRegulatorSetIndex : regulatorSetIndex,
      TabCardHead.kExclude           : exclude,
    };

    await db.update(TabCardHead.tabName, updateRow, where: '${TabCardHead.kCardID} = ?', whereArgs: [cardID]);
  }

  @override
  Future<List<String>> getFileCardKeyList({ required int jsonFileID }) async {
    final rows = await db.query(TabCardHead.tabName, distinct: true,
      columns   : [TabCardHead.kCardKey],
      where     : '${TabCardHead.kJsonFileID} = ?',
      whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
  }

  @override
  Future<List<String>> getFileGroupList({ required int jsonFileID }) async {
    final rows = await db.query(TabCardHead.tabName, distinct: true,
        columns   : [TabCardHead.kGroup],
        where     : '${TabCardHead.kJsonFileID} = ?',
        whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
  }

  @override
  Future<int?> getCardIdFromKey({ required int jsonFileID, required String cardKey}) async {
    final rows = await db.query(TabCardHead.tabName, distinct: true,
        columns   : [TabCardHead.kCardID],
        where     : '${TabCardHead.kJsonFileID} = ? AND ${TabCardHead.kCardKey} = ?',
        whereArgs : [jsonFileID, cardKey]
    );

    if (rows.isEmpty) return null;

    final cardID = rows.first.values.first as int;

    return cardID;
  }

}

class TabCardTagFlt extends TabCardTag {
  static const String createQuery = "CREATE TABLE ${TabCardTag.tabName} ("
      "${TabCardTag.kID}             INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabCardTag.kJsonFileID}     INTEGER,"
      "${TabCardTag.kCardID}         INTEGER,"
      "${TabCardTag.kTag}            TEXT"
      ")";

  final Database db;
  TabCardTagFlt(this.db);

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabCardTag.tabName, where: '${TabCardTag.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<void> insertRow({ required int jsonFileID, required int cardID, required String tag}) async {
    final Map<String, Object?> row = {
      TabCardTag.kJsonFileID     : jsonFileID,
      TabCardTag.kCardID         : cardID,
      TabCardTag.kTag            : tag
    };

    await db.insert(TabCardTag.tabName, row);
  }

  @override
  Future<List<String>> getCardTags({required int jsonFileID, required int cardID}) async {
    final rows = await db.query(TabCardTag.tabName,
        columns   : [TabCardTag.kTag],
        where     : '${TabCardTag.kJsonFileID} = ? and ${TabCardTag.kCardID} = ?',
        whereArgs : [jsonFileID, cardID]
    );

    return rows.map((row) => row.values.first as String).toList();
  }

  @override
  Future<List<String>> getFileTagList({ required int jsonFileID }) async {
    final rows = await db.query(TabCardTag.tabName, distinct: true,
        columns   : [TabCardTag.kTag],
        where     : '${TabCardTag.kJsonFileID} = ?',
        whereArgs : [jsonFileID]
    );

    final result = rows.map((row) => row.values.first as String).toList();
    return result;
  }

}

class TabCardLinkFlt extends TabCardLink {
  static const String createQuery = "CREATE TABLE ${TabCardLink.tabName} ("
      "${TabCardLink.kLinkID}         INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabCardLink.kJsonFileID}     INTEGER,"
      "${TabCardLink.kCardID}         INTEGER,"
      "${TabCardLink.kQualityName}    TEXT"
      ")";

  final Database db;
  TabCardLinkFlt(this.db);

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabCardLink.tabName, where: '${TabCardLink.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<int> insertRow({ required int jsonFileID, required int cardID, required String qualityName}) async {
    final Map<String, Object?> row = {
      TabCardLink.kJsonFileID     : jsonFileID,
      TabCardLink.kCardID         : cardID,
      TabCardLink.kQualityName    : qualityName,
    };

    final ret = await db.insert(TabCardLink.tabName, row);
    return ret;
  }
}

class TabCardLinkTagFlt extends TabCardLinkTag {
  static const String createQuery = "CREATE TABLE ${TabCardLinkTag.tabName} ("
      "${TabCardLinkTag.kID}          INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabCardLinkTag.kJsonFileID}  INTEGER,"
      "${TabCardLinkTag.kLinkID}      INTEGER,"
      "${TabCardLinkTag.kTag}         TEXT"
      ")";

  final Database db;
  TabCardLinkTagFlt(this.db);

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabCardLinkTag.tabName, where: '${TabCardLinkTag.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<void> insertRow({ required int jsonFileID, required int linkId, required String tag}) async {
    final Map<String, Object?> row = {
      TabCardLinkTag.kJsonFileID : jsonFileID,
      TabCardLinkTag.kLinkID     : linkId,
      TabCardLinkTag.kTag        : tag
    };

    await db.insert(TabCardLinkTag.tabName, row);
  }
}

class TabCardBodyFlt extends TabCardBody {
  static const String createQuery = "CREATE TABLE ${TabCardBody.tabName} ("
      "${TabCardBody.kID}         INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabCardBody.kJsonFileID} INTEGER,"
      "${TabCardBody.kCardID}     INTEGER,"
      "${TabCardBody.kBodyNum}    INTEGER,"
      "${TabCardBody.kJson}       TEXT"
      ")";

  final Database db;
  TabCardBodyFlt(this.db);

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabCardBody.tabName, where: '${TabCardBody.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<void> insertRow({ required int jsonFileID, required int cardID, required int bodyNum, required String json }) async {
    final Map<String, Object?> row = {
      TabCardBody.kJsonFileID : jsonFileID,
      TabCardBody.kCardID     : cardID,
      TabCardBody.kBodyNum    : bodyNum,
      TabCardBody.kJson       : json
    };

    await db.insert(TabCardBody.tabName, row);
  }

  @override
  Future<Map<String, dynamic>?> getRow({ required int jsonFileID, required int cardID, required int bodyNum }) async {
    final rows = await db.query(TabCardBody.tabName,
        where     : '${TabCardBody.kJsonFileID} = ? and ${TabCardBody.kCardID} = ? and ${TabCardBody.kBodyNum} = ?',
        whereArgs : [jsonFileID, cardID, bodyNum]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];

    final String jsonStr = (row[TabCardBody.kJson]) as String;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

    row.forEach((key, value) {
      jsonMap[key] = value;
    });

    return jsonMap;
  }
}

class TabTemplateSourceFlt extends TabTemplateSource {
  static const String _kJson = 'json';

  static const String createQuery = "CREATE TABLE ${TabTemplateSource.tabName} ("
      "${TabTemplateSource.kSourceID}   INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabTemplateSource.kJsonFileID} INTEGER,"
      "$_kJson                          TEXT"
      ")";

  final Database db;
  TabTemplateSourceFlt(this.db);

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabTemplateSource.tabName, where: '${TabTemplateSource.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<int> insertRow({required int jsonFileID, required Map<String, dynamic> source}) async {
    final jsonStr = jsonEncode(source);
    final Map<String, Object?> row = {
      TabTemplateSource.kJsonFileID : jsonFileID,
      _kJson                        : jsonStr
    };

    final id = await db.insert(TabTemplateSource.tabName, row);
    return id;
  }

  @override
  Future<Map<String, dynamic>?> getRow({required int jsonFileID, required int sourceId}) async {
    final rows = await db.query(TabTemplateSource.tabName,
        where     : '${TabTemplateSource.kJsonFileID} = ? and ${TabTemplateSource.kSourceID} = ?',
        whereArgs : [jsonFileID, sourceId]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];

    final String jsonStr = (row[_kJson]) as String;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

    return jsonMap;
  }
}

class TabFileUrlMapFlt extends TabFileUrlMap {
  static const String _kID = 'id';

  static const String createQuery = "CREATE TABLE ${TabFileUrlMap.tabName} ("
      "$_kID                        INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabFileUrlMap.kJsonFileID} INTEGER,"
      "${TabFileUrlMap.kPath}       TEXT,"
      "${TabFileUrlMap.kUrl}        TEXT"
      ")";

  final Database db;
  TabFileUrlMapFlt(this.db);

  final _fileUrlMap = <String, String>{};

  Future<void> init() async {
    _fileUrlMap.clear();

    final rows = await db.query(TabFileUrlMap.tabName);
    for (var row in rows) {
      final path = '${row[TabFileUrlMap.kJsonFileID]}|${row[TabFileUrlMap.kPath]}';
      final url  = row[TabFileUrlMap.kUrl] as String;
      _fileUrlMap[path] = url;
    }
  }

  @override
  Future<void> deleteJsonFile(int jsonFileID) async {
    await db.delete(TabFileUrlMap.tabName, where: '${TabFileUrlMap.kJsonFileID} = ?', whereArgs: [jsonFileID]);
  }

  @override
  Future<void> insertRows({required int jsonFileID, required Map<String, String> fileUrlMap}) async {
    for (var entry in fileUrlMap.entries) {
      final Map<String, Object?> row = {
        TabFileUrlMap.kJsonFileID : jsonFileID,
        TabFileUrlMap.kPath       : entry.key,
        TabFileUrlMap.kUrl        : entry.value,
      };

      await db.insert(TabFileUrlMap.tabName, row);
    }
  }

  /// important, this function mast by synchronous
  @override
  String? getFileUrl({required int jsonFileID, required String fileName}) {
    final url = _fileUrlMap['$jsonFileID|$fileName'];
    return url;
  }

  @override
  Future<void> deleteRow({required int jsonFileID, required String fileName}) async {
    await db.delete(TabFileUrlMap.tabName, where: '${TabFileUrlMap.kJsonFileID} = ? and ${TabFileUrlMap.kPath} = ?', whereArgs: [jsonFileID, fileName]);
  }

  @override
  Future<void> insertRow({required int jsonFileID, required String fileName, required String url}) async {
    final Map<String, Object?> row = {
      TabFileUrlMap.kJsonFileID : jsonFileID,
      TabFileUrlMap.kPath       : fileName,
      TabFileUrlMap.kUrl        : url,
    };

    await db.insert(TabFileUrlMap.tabName, row);
  }
}

class TabCardStatFlt extends TabCardStat {
  static const String createQuery = "CREATE TABLE ${TabCardStat.tabName} ("
      "${TabCardStat.kID}              INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabCardStat.kJsonFileID}      INTEGER,"
      "${TabCardStat.kCardID}          INTEGER,"
      "${TabCardStat.kCardKey}         TEXT,"
      "${TabCardStat.kCardGroupKey}    TEXT,"
      "${TabCardStat.kQuality}         INTEGER,"
      "${TabCardStat.kQualityFromDate} INTEGER,"
      "${TabCardStat.kStartDate}       INTEGER,"
      "${TabCardStat.kLastTestDate}    INTEGER,"
      "${TabCardStat.kLastResult}      INTEGER,"
      "${TabCardStat.kTestsCount}      INTEGER,"
      "${TabCardStat.kJson}            TEXT"
      ")";

  final Database db;
  TabCardStatFlt(this.db);

  /// removes cards that are not on the list
  @override
  Future<void> removeOldCard(int jsonFileID, List<String> cardKeyList) async {
    final rows = await db.query(TabCardStat.tabName,
      columns   : [TabCardStat.kCardKey],
      where     : '${TabCardStat.kJsonFileID} = ?',
      whereArgs : [jsonFileID]
    );

    for (var row in rows) {
      final String cardKey = row[TabCardStat.kCardKey] as String;
      if (!cardKeyList.contains(cardKey)){
        db.delete(TabCardStat.tabName,
          where     : '${TabCardStat.kJsonFileID} = ? and ${TabCardStat.kCardKey} = ?',
          whereArgs : [jsonFileID, cardKey]
        );
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> getRow({required int jsonFileID, required int cardID}) async {
    final rows = await db.query(TabCardStat.tabName,
        where     : '${TabCardStat.kCardID} = ?',
        whereArgs : [cardID]
    );

    if (rows.isEmpty) return null;

    final row = rows[0];
    return row;
  }

  @override
  Future<int> insertRow({
    required int    jsonFileID,
    required int    cardID,
    required String cardKey,
    required String cardGroupKey,
  }) async {
    Map<String, Object> row = {
      TabCardStat.kJsonFileID      : jsonFileID,
      TabCardStat.kCardID          : cardID,
      TabCardStat.kCardKey         : cardKey,
      TabCardStat.kCardGroupKey    : cardGroupKey,
      TabCardStat.kQuality         : 0,
      TabCardStat.kLastResult      : false,
      TabCardStat.kQualityFromDate : 0,
      TabCardStat.kStartDate       : 0,
      TabCardStat.kTestsCount      : 0,
      TabCardStat.kJson            : '',
    };

    final id = await db.insert(TabCardStat.tabName, row);
    return id;
  }

  @override
  Future<int> insertRowFromMap(Map<String, dynamic> rowMap) async {
    final id = await db.insert(TabCardStat.tabName, rowMap);
    return id;
  }

  @override
  Future<void> clear() async {
    await db.delete(TabCardStat.tabName);
  }

  @override
  Future<List<Map<String, Object?>>> getAllRows() async {
    final rows = await db.query(TabCardStat.tabName,
      where: '${TabCardStat.kQuality} > ?',
      whereArgs: [0],
    );
    return rows;
  }

  @override
  Future<bool> updateRow(int jsonFileID, int cardID, Map<String, Object?> map) async {
    final count = await db.update(TabCardStat.tabName, map,
      where: '${TabCardStat.kJsonFileID} = ? AND ${TabCardStat.kCardID} = ?',
      whereArgs: [jsonFileID, cardID]
    );
    return count > 0;
  }
}

class TabTestResultFlt extends TabTestResult  {
  static const String createQuery = "CREATE TABLE ${TabTestResult.tabName} ("
      "${TabTestResult.kID}            INTEGER PRIMARY KEY AUTOINCREMENT,"
      "${TabTestResult.kFileGuid}      TEXT,"
      "${TabTestResult.kFileVersion}   INTEGER,"
      "${TabTestResult.kCardID}        TEXT,"
      "${TabTestResult.kBodyNum}       INTEGER,"
      "${TabTestResult.kResult}        INTEGER,"
      "${TabTestResult.kEarned}        INTEGER,"
      "${TabTestResult.kTryCount}      INTEGER,"
      "${TabTestResult.kSolveTime}     INTEGER,"
      "${TabTestResult.kDateTime}      INTEGER,"
      "${TabTestResult.kQualityBefore} INTEGER,"
      "${TabTestResult.kQualityAfter}  INTEGER,"
      "${TabTestResult.kDifficulty}    INTEGER"
      ")";

  final Database db;

  TabTestResultFlt(this.db);

  @override
  Future<int> insertRow(TestResult testResult) async {
    Map<String, Object> row = {
      TabTestResult.kFileGuid      : testResult.fileGuid,
      TabTestResult.kFileVersion   : testResult.fileVersion,
      TabTestResult.kCardID        : testResult.cardID,
      TabTestResult.kBodyNum       : testResult.bodyNum,
      TabTestResult.kResult        : testResult.result,
      TabTestResult.kEarned        : testResult.earned,
      TabTestResult.kTryCount      : testResult.tryCount,
      TabTestResult.kSolveTime     : testResult.solveTime,
      TabTestResult.kDateTime      : testResult.dateTime,
      TabTestResult.kQualityBefore : testResult.qualityBefore,
      TabTestResult.kQualityAfter  : testResult.qualityAfter,
      TabTestResult.kDifficulty    : testResult.difficulty,
    };

    final id = await db.insert(TabTestResult.tabName, row);
    return id;
  }

  @override
  Future<List<TestResult>> getForPeriod(int fromDate, int toDate) async {
    final resultList = <TestResult>[];

    final rows = await db.query(TabTestResult.tabName,
        where     : '${TabTestResult.kDateTime} >= ? and ${TabTestResult.kDateTime} <= ?',
        whereArgs : [fromDate, toDate]
    );

    for (var row in rows) {
      resultList.add(TestResult.fromMap(row));
    }

    return resultList;
  }

  @override
  Future<int> getFirstTime() async {
    final rows = await db.rawQuery('SELECT MIN(${TabTestResult.kDateTime}) as dateTime FROM ${TabTestResult.tabName}');
    if (rows.isEmpty) return 0;
    return (rows.first.values.first??0) as int;
  }

  @override
  Future<int> getLastTime() async {
    final rows = await db.rawQuery('SELECT MAX(${TabTestResult.kDateTime}) as dateTime FROM ${TabTestResult.tabName}');
    if (rows.isEmpty) return 0;
    return (rows.first.values.first??0) as int;
  }
}

class DbSourceFlt extends DbSource {
  final Database db;
  DbSourceFlt(this.db);

  static Future<DbSourceFlt> create(String dbPath) async {
    final decardDB = DecardDB(dbPath);
    await decardDB.init();
    final db       = decardDB.database;

    final dbSource = DbSourceFlt(db);

    dbSource.tabSourceFile     = TabSourceFileFlt(db);
    dbSource.tabJsonFile       = TabJsonFileFlt(db);
    dbSource.tabCardHead       = TabCardHeadFlt(db);
    dbSource.tabCardTag        = TabCardTagFlt(db);
    dbSource.tabCardLink       = TabCardLinkFlt(db);
    dbSource.tabCardLinkTag    = TabCardLinkTagFlt(db);
    dbSource.tabCardBody       = TabCardBodyFlt(db);
    dbSource.tabCardStyle      = TabCardStyleFlt(db);
    dbSource.tabQualityLevel   = TabQualityLevelFlt(db);
    dbSource.tabTemplateSource = TabTemplateSourceFlt(db);
    dbSource.tabFileUrlMap     = TabFileUrlMapFlt(db);
    dbSource.tabCardStat       = TabCardStatFlt(db);
    dbSource.tabTestResult     = TabTestResultFlt(db);

    await dbSource.init();

    return dbSource;
  }
  
  @override
  Future<void> init() async {
    await (tabJsonFile   as TabJsonFileFlt).init();
    await (tabFileUrlMap as TabFileUrlMapFlt).init();
  }
}

class DecardDB {
  final String dbPath;
  
  DecardDB(this.dbPath);

  late Database database;

  Future<void> init() async {
    String path = join(dbPath, "decard.db");
    database = await openDatabase(path, version: 1, onOpen: (db) {},
      onCreate: (Database db, int version) async {
          await _createTables(db);
    });
  }

  _createTables(Database db) async {
    await db.execute(TabSourceFileFlt.createQuery);
    await db.execute(TabJsonFileFlt.createQuery);
    await db.execute(TabCardStyleFlt.createQuery);
    await db.execute(TabQualityLevelFlt.createQuery);
    await db.execute(TabCardHeadFlt.createQuery);
    await db.execute(TabCardTagFlt.createQuery);
    await db.execute(TabCardLinkFlt.createQuery);
    await db.execute(TabCardLinkTagFlt.createQuery);
    await db.execute(TabCardBodyFlt.createQuery);
    await db.execute(TabTemplateSourceFlt.createQuery);
    await db.execute(TabFileUrlMapFlt.createQuery);
    await db.execute(TabCardStatFlt.createQuery);
    await db.execute(TabTestResultFlt.createQuery);
  }

  deleteDB( ) async {
    deleteDatabase(database.path);
  }
}
