import 'dart:convert';
import 'dart:core';

import 'decardj.dart';
import 'loader.dart';

abstract class TabSourceFile {
  static const String tabName         = 'SourceFile';

  static const String kSourceFileID   = 'SourceFileID';
  static const String kFilePath       = 'filePath';
  static const String kChangeDateTime = 'changeDateTime';
  static const String kSize           = 'size';

  Future<bool> checkFileRegistered(String path, DateTime changeDateTime, int size);

  Future<int> registerFile(String path, DateTime changeDateTime, int size);

  Future<Map<String, dynamic>?> getRow({ required int sourceFileID});
}

class FileKey {
  final String guid;
  final int version;
  final int jsonFileID;
  FileKey(this.guid, this.version, this.jsonFileID);
}

/// Loaded json files
abstract class TabJsonFile {
  static const String tabName       = 'JsonFile';

  static const String kJsonFileID   = 'jsonFileID';
  static const String kSourceFileID = 'sourceFileID';
  static const String kRootPath     = 'rootPath';
  static const String kLoadTime     = 'loadTime';
  static const String kTitle        = DjfFile.title;
  static const String kGuid         = DjfFile.guid;
  static const String kVersion      = DjfFile.version;
  static const String kAuthor       = DjfFile.author;
  static const String kSite         = DjfFile.site;
  static const String kEmail        = DjfFile.email;
  static const String kLicense      = DjfFile.license;

  FileKey jsonFileIdToFileKey(int jsonFileId);

  int? fileGuidToJsonFileId(String guid, int version);

  Future<List<Map<String, Object?>>> getRowByGuid(String guid, {int? version});

  Future<Map<String, dynamic>?> getRowBySourceID({required String sourceFileID});

  // return jsonFileID
  Future<int> insertRow(String sourceFileID, String rootPath, Map jsonMap);

  Future<Map<String, dynamic>?> getRow({required int jsonFileID});

  Future<List<Map<String, Object?>>> getAllRows();

  Future<void> deleteJsonFile(int jsonFileID);
}

abstract class TabCardStyle {
  static const String tabName        = 'CardStyle';

  static const String kID            = 'id';
  static const String kJsonFileID    = TabJsonFile.kJsonFileID;
  static const String kCardStyleKey  = 'cardStyleKey';  // map from DjfCardStyle.id
  static const String kJson          = 'json';          // style data are stored as json, when needed they are unpacked

  Future<void> deleteJsonFile(int jsonFileID);

  Future<void> insertRow({ required int jsonFileID, required String cardStyleKey, required String jsonStr });

  Future<Map<String, dynamic>?> getRow({ required int jsonFileID, required String cardStyleKey });
  Future<List<String>> getStyleKeyList({ required int jsonFileID});

  /// mast by called from getRow for return result
  Map<String, dynamic>? getRowPrepare(Map<String, dynamic>? row) {
    if (row == null) return null;

    final String jsonStr = (row[kJson]) as String;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

    jsonMap.addEntries(row.entries.where((element) => element.key != kJson));

    return jsonMap;
  }
}

abstract class TabQualityLevel {
  static const String tabName        = 'QualityLevel';

  static const String kID            = 'id';
  static const String kJsonFileID    = TabJsonFile.kJsonFileID;
  static const String kQualityName   = 'qualityName'; // map from DjfQualityLevel.qualityName
  static const String kMinQuality    = DjfQualityLevel.minQuality;
  static const String kAvgQuality    = DjfQualityLevel.avgQuality;

  Future<void> insertRow({ required int jsonFileID, required String qualityName, required int minQuality, required int avgQuality });
  Future<List<String>> getLevelNameList({required int jsonFileID});

  Future<void> deleteJsonFile(int jsonFileID);
}

abstract class TabCardHead {
  static const String tabName        = 'CardHead';

  static const String kCardID        = 'cardID';
  static const String kJsonFileID    = TabJsonFile.kJsonFileID;
  static const String kCardKey       = 'cardKey'; // map from DjfCard.id
  static const String kTitle         = DjfCard.title;
  static const String kHelp          = DjfCard.help;
  static const String kDifficulty    = DjfCard.difficulty;
  static const String kGroup         = 'groupKey'; // map from DjfCard.group;
  static const String kBodyCount     = 'bodyCount'; // number of records in the DjfCard.bodyList
  static const String kExclude       = 'exclude'; // card excluded from use

  static const String kCardListIndex = 'cardListIndex'; // row number in cardList of template cardList or root cardList
  static const String kTemplateIndex = 'templateIndex'; // row number in templateList
  static const String kSourceIndex   = 'sourceIndex'; // template source row index in templatesSources
  static const String kSourceRowId   = 'sourceRowId'; // template source row from which was generated card

  static const String kRegulatorSetIndex   = 'regulatorSetIndex'; // index of set in Regulator.setList

  Future<void> deleteJsonFile(int jsonFileID);

  Future<int> insertRow({
    required int    jsonFileID,
    required String cardKey,
    required String title,
    required String help,
    required int    difficulty,
    required String cardGroupKey,
    required int    bodyCount,
    required int    cardListIndex,

    int? templateIndex,
    int? sourceIndex,
    int? sourceRowId,
  });

  Future<Map<String, dynamic>?> getRow({required int jsonFileID, required int cardID});

  Future<int> getGroupCardCount({ required int jsonFileID, required cardGroupKey});
  Future<List<String>> getFileCardKeyList({ required int jsonFileID});
  Future<List<String>> getFileGroupList({ required int jsonFileID});
  Future<int?> getCardIdFromKey({ required int jsonFileID, required String cardKey});

  Future<List<Map<String, Object?>>> getAllRows();
  Future<List<Map<String, Object?>>> getFileRows({ required int jsonFileID});
  Future<void> clearRegulatorPatchOnAllRow();
  Future<void> setRegulatorPatchOnCard({required int jsonFileID, required int cardID, required int regulatorSetIndex, required bool exclude});
}

abstract class TabCardTag {
  static const String tabName         = 'CardTag';

  static const String kID             = 'id';
  static const String kJsonFileID     = TabJsonFile.kJsonFileID;
  static const String kCardID         = TabCardHead.kCardID;
  static const String kTag            = 'tag';

  Future<void> deleteJsonFile(int jsonFileID);

  Future<void> insertRow({ required int jsonFileID, required int cardID, required String tag});
  Future<List<String>> getFileTagList({ required int jsonFileID});

  Future<List<String>> getCardTags({required int jsonFileID, required int cardID});
}

abstract class TabCardLink {
  static const String tabName         = 'CardLink';

  static const String kLinkID         = 'linkID';
  static const String kLinkIndex      = 'linkIndex'; // row num in card.upLinks list
  static const String kJsonFileID     = TabJsonFile.kJsonFileID;
  static const String kCardID         = TabCardHead.kCardID;
  static const String kQualityName    = 'qualityName';

  Future<void> deleteJsonFile(int jsonFileID);

  Future<int> insertRow({required int jsonFileID, required int cardID, required String qualityName, required int linkIndex});
  Future<List<Map<String, dynamic>>> getFileRowList({required int jsonFileID});
}

abstract class TabCardLinkTag {
  static const String tabName  = 'CardLinkTag';

  static const String kID         = 'id';
  static const String kJsonFileID = TabJsonFile.kJsonFileID;
  static const String kLinkID     = TabCardLink.kLinkID;
  static const String kTag        = 'tag';

  Future<void> deleteJsonFile(int jsonFileID);

  Future<void> insertRow({ required int jsonFileID, required int linkId, required String tag});
  Future<List<Map<String, dynamic>>> getFileRowList({required int jsonFileID});
}

class BodyKey {
  final int cardID;
  final int bodyNum;
  BodyKey(this.cardID, this.bodyNum);
}

abstract class TabCardBody {
  static const String tabName     = 'CardBody';

  static const String kID         = 'id';
  static const String kJsonFileID = TabJsonFile.kJsonFileID;
  static const String kCardID     = TabCardHead.kCardID;
  static const String kBodyNum    = 'bodyNum'; // the card can have many bodies, the body number is stored here
  static const String kJson       = 'json';    // card body data are stored as json, when needed they are unpacked

  Future<void> deleteJsonFile(int jsonFileID);

  Future<void> insertRow({ required int jsonFileID, required int cardID, required int bodyNum, required String json });

  Future<Map<String, dynamic>?> getRow({ required int jsonFileID, required int cardID, required int bodyNum });

  /// mast by called from getRow for return result
  Map<String, dynamic>? getRowPrepare(Map<String, dynamic>? row) {
    if (row == null) return null;

    final String jsonStr = (row[kJson]) as String;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

    jsonMap.addEntries(row.entries.where((element) => element.key != kJson));

    return jsonMap;
  }

  Future<List<BodyKey>> getFileKeyList({required int jsonFileID});
}

abstract class TabTemplateSource {
  static const String tabName         = 'TemplateSource';

  static const String kSourceID       = 'sourceID';
  static const String kJsonFileID     = TabJsonFile.kJsonFileID;

  Future<void> deleteJsonFile(int jsonFileID);

  Future<int> insertRow({required int jsonFileID, required Map<String, dynamic> source});

  Future<Map<String, dynamic>?> getRow({required int jsonFileID, required int sourceId});
}

abstract class TabFileUrlMap {
  static const String tabName     = 'FileUrlMap';

  static const String kJsonFileID = TabJsonFile.kJsonFileID;
  static const String kPath       = 'path';
  static const String kUrl        = 'url';

  Future<void> deleteJsonFile(int jsonFileID);

  Future<void> insertRows({required int jsonFileID, required Map<String, String> fileUrlMap});

  /// important, this function mast by synchronous
  String? getFileUrl({required int jsonFileID, required String fileName});

  Future<void> deleteRow({required int jsonFileID, required String fileName});

  Future<void> insertRow({required int jsonFileID, required String fileName, required String url});
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

class CardStatExchange {
  static const String kFileGuid = "fileGuid";
  static const String kVersion  = "version";
  static const String kCardID   = "cardID";

  static DbSource? dbSource; // for time fromMap / toJson

  final String fileGuid;
  final int    version;
  final String cardID;            // == json Card.id
  final int    quality;           // studying quality, 100 - card is completely studied; 0 - minimum studying quality
  final int    qualityFromDate;   // the first date taken into account when calculating quality
  final int    startDate;         // date of studying beginning
  final int    lastTestDate;      // date of last test
  final int    testsCount;        // number of tests

  CardStatExchange({
    required this.fileGuid,
    required this.version,
    required this.cardID,
    required this.quality,
    required this.qualityFromDate,
    required this.startDate,
    required this.lastTestDate,
    required this.testsCount,
  });

  factory CardStatExchange.fromDbMap(Map<String, dynamic> json) {
    // child -> server
    // for output to server from child device DB
    final fileKey = dbSource!.tabJsonFile.jsonFileIdToFileKey(json[TabCardStat.kJsonFileID]);
    return CardStatExchange(
      fileGuid          : fileKey.guid,
      version           : fileKey.version,
      cardID            : json[TabCardStat.kCardKey],
      quality           : json[TabCardStat.kQuality],
      qualityFromDate   : json[TabCardStat.kQualityFromDate],
      startDate         : json[TabCardStat.kStartDate],
      lastTestDate      : json[TabCardStat.kLastTestDate]??0,
      testsCount        : json[TabCardStat.kTestsCount],
    );
  }

  factory CardStatExchange.fromJson(Map<String, dynamic> json) {
    // server -> child
    // for load from server to child DB
    return CardStatExchange(
      fileGuid          : json[kFileGuid],
      version           : json[kVersion],
      cardID            : json[kCardID],
      quality           : json[TabCardStat.kQuality],
      qualityFromDate   : json[TabCardStat.kQualityFromDate],
      startDate         : json[TabCardStat.kStartDate],
      lastTestDate      : json[TabCardStat.kLastTestDate]??0,
      testsCount        : json[TabCardStat.kTestsCount],
    );
  }

  Future<Map<String, dynamic>> toDbMap() async {
    // server -> child
    // make map for save to DB tab TabCardStat

    final jsonFileID = dbSource!.tabJsonFile.fileGuidToJsonFileId(fileGuid, version);
    if (jsonFileID == null) return {};

    final cardDBID = await dbSource!.tabCardHead.getCardIdFromKey(jsonFileID: jsonFileID, cardKey: cardID);
    if (cardDBID == null) return {};

    final row = (await dbSource!.tabCardHead.getRow(jsonFileID: jsonFileID, cardID: cardDBID))!;
    final String groupKey = row[TabCardHead.kGroup]??'';

    Map<String, dynamic> map = {
      TabCardStat.kJsonFileID      : jsonFileID,
      TabCardStat.kCardID          : cardDBID,
      TabCardStat.kCardKey         : cardID,
      TabCardStat.kCardGroupKey    : groupKey,
      TabCardStat.kQuality         : quality,
      TabCardStat.kQualityFromDate : qualityFromDate,
      TabCardStat.kStartDate       : startDate,
      TabCardStat.kLastTestDate    : lastTestDate,
      TabCardStat.kTestsCount      : testsCount,
    };

    return map;
  }

  Map<String, dynamic> toJson(){
    // child -> server
    // for make json and save it to server

    Map<String, dynamic> map = {
      kFileGuid                    : fileGuid,
      kCardID                      : cardID,
      TabCardStat.kQuality         : quality,
      TabCardStat.kQualityFromDate : qualityFromDate,
      TabCardStat.kStartDate       : startDate,
      TabCardStat.kLastTestDate    : lastTestDate,
      TabCardStat.kTestsCount      : testsCount,
    };

    return map;
  }
}

abstract class TabCardStat {
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

  /// removes cards that are not on the list
  Future<void> removeOldCard(int jsonFileID, List<String> cardKeyList);

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

  Future<Map<String, dynamic>?> getRow({required int jsonFileID, required int cardID});

  Future<int> insertRow({
    required int    jsonFileID,
    required int    cardID,
    required String cardKey,
    required String cardGroupKey,
  });

  Future<int> insertRowFromMap(Map<String, dynamic> rowMap);

  Future<void> clear();

  Future<List<Map<String, Object?>>> getAllRows();

  Future<bool> updateRow(int jsonFileID, int cardID, Map<String, Object?> map);
}

/// For card result log
class TestResult {
  final String fileGuid;
  final int    fileVersion;
  final String cardID;  // == json Card.id
  final int    bodyNum;
  final bool   result;
  final double earned;
  final int    tryCount;
  final int    solveTime;
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
    required this.tryCount,
    required this.solveTime,
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
      earned        : _isDouble(json[TabTestResult.kEarned]),
      tryCount      : json[TabTestResult.kTryCount     ]??1,
      solveTime     : json[TabTestResult.kSolveTime    ]??0,
      dateTime      : json[TabTestResult.kDateTime     ],
      qualityBefore : json[TabTestResult.kQualityBefore],
      qualityAfter  : json[TabTestResult.kQualityAfter ],
      difficulty    : json[TabTestResult.kDifficulty   ],
    );
  }

  static double _isDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
    TabTestResult.kFileGuid      : fileGuid,
    TabTestResult.kFileVersion   : fileVersion,
    TabTestResult.kCardID        : cardID,
    TabTestResult.kBodyNum       : bodyNum,
    TabTestResult.kResult        : result,
    TabTestResult.kEarned        : earned,
    TabTestResult.kTryCount      : tryCount,
    TabTestResult.kSolveTime     : solveTime,
    TabTestResult.kDateTime      : dateTime,
    TabTestResult.kQualityBefore : qualityBefore,
    TabTestResult.kQualityAfter  : qualityAfter,
    TabTestResult.kDifficulty    : difficulty,
  };
}

abstract class TabTestResult {
  static const String tabName = 'TestResult';

  static const String kID            = 'id';
  static const String kFileGuid      = "fileGuid";
  static const String kFileVersion   = "fileVersion";
  static const String kCardID        = "cardID";
  static const String kBodyNum       = "bodyNum";
  static const String kResult        = "result";
  static const String kEarned        = "earned";
  static const String kTryCount      = "tryCount";
  static const String kSolveTime     = "solveTime";
  static const String kDateTime      = "dateTime";
  static const String kQualityBefore = "qualityBefore";
  static const String kQualityAfter  = "qualityAfter";
  static const String kDifficulty    = "difficulty";

  Future<int> insertRow(TestResult testResult);

  Future<List<TestResult>> getForPeriod(int fromDate, int toDate);

  Future<int> getFirstTime();

  Future<int> getLastTime();
}



abstract class DbSource {
  late TabSourceFile     tabSourceFile;
  late TabJsonFile       tabJsonFile;
  late TabCardHead       tabCardHead;
  late TabCardTag        tabCardTag;
  late TabCardLink       tabCardLink;
  late TabCardLinkTag    tabCardLinkTag;
  late TabCardBody       tabCardBody;
  late TabCardStyle      tabCardStyle;
  late TabQualityLevel   tabQualityLevel;
  late TabTemplateSource tabTemplateSource;
  late TabFileUrlMap     tabFileUrlMap;

  late TabCardStat       tabCardStat;
  late TabTestResult     tabTestResult;

  late DataLoader _loader;

  DbSource() {
    _loader = DataLoader(this);
  }

  Future<int?> loadJson({required String sourceFileID, required String rootPath, required Map<String, dynamic> jsonMap, required Map<String, String> fileUrlMap, bool onlyLastVersion = false, bool reInitDB = true}) async {
    final jsonFileID = await _loader.loadJson(sourceFileID, rootPath, jsonMap, onlyLastVersion);

    if (jsonFileID == null) return null;

    await tabFileUrlMap.insertRows(jsonFileID: jsonFileID, fileUrlMap: fileUrlMap);

    if (reInitDB) {
      await init();
    }

    return jsonFileID;
  }

  String? getFileUrl(int jsonFileID, String fileName) {
    final result = tabFileUrlMap.getFileUrl(jsonFileID: jsonFileID, fileName: fileName);
    if (result != null) return result;
    return null;
  }

  Future<void> init();

  Future<void> deleteJsonFile(int jsonFileID) async {
    await tabJsonFile.deleteJsonFile(jsonFileID);
    await tabCardHead.deleteJsonFile(jsonFileID);
    await tabCardTag.deleteJsonFile(jsonFileID);
    await tabCardLink.deleteJsonFile(jsonFileID);
    await tabCardLinkTag.deleteJsonFile(jsonFileID);
    await tabCardBody.deleteJsonFile(jsonFileID);
    await tabCardStyle.deleteJsonFile(jsonFileID);
    await tabQualityLevel.deleteJsonFile(jsonFileID);
    await tabTemplateSource.deleteJsonFile(jsonFileID);
    await tabFileUrlMap.deleteJsonFile(jsonFileID);
  }
}