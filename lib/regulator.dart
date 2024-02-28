import 'dart:io';
import 'dart:convert';

import 'db.dart';

/// Manage the selection and execution of cards on the child's device
class DrfRegulator {
  static const String options        = "options"; // options, mainly settings for the card selection mechanism
  static const String setList        = "setList"; // array of sets, filtering and customizing cards
  static const String difficultyList = "difficultyList"; // array of difficulty, card execution settings according to their difficulty
}

/// Options, mainly settings for the card selection mechanism
class DrfOptions {
  static const String hotDayCount = "hotDayCount";   // Number of days for which the statistics are calculated

  static const String hotCardQualityTopLimit = "hotCardQualityTopLimit"; // cards with lower quality are considered to be actively studied
  static const String maxCountHotCard = "maxCountHotCard";        // Maximum number of cards in active study

  /// limits to determine the activity of the group
  static const String hotGroupMinQualityTopLimit = "hotGroupMinQualityTopLimit"; // Minimum quality for the cards included in the group
  static const String hotGroupAvgQualityTopLimit = "hotGroupAvgQualityTopLimit"; // Average quality of the cards included in the group

  /// the minimum number of active study groups,
  /// If the quantity is less than the limit - the system tries to select a card from the new group
  static const String minCountHotQualityGroup = "minCountHotQualityGroup";

  static const String lowGroupAvgQualityTopLimit = "lowGroupAvgQualityTopLimit"; // 

  /// maximal number of groups in the begin stage of the study,
  /// If the number is equal to the limit - the system selects cards from the groups already being studied
  static const String maxCountLowQualityGroup = "maxCountLowQualityGroup";

  /// Decrease the quality when the amount of statistics is small
  ///   if the new card has very good results from the beginning
  ///   these parameters will not let the quality grow too fast
  static const String lowTryCount = "lowTryCount"; // minimum number of tests
  static const String lowDayCount = "lowDayCount"; // Minimum number of days

  /// Maximum available quality with a negative last result
  static const String negativeLastResultMaxQualityLimit = "negativeLastResultMaxQualityLimit";

  /// minimum earnings count minutes that can be transferred outside
  static const String minEarnTransferMinutes = 'minEarnTransferMinutes';
}

/// Filtering and customizing cards
class DrfCardSet {
  static const String fileGUID = "fileGUID"; // GUID of decardj file
  static const String cards    = "cards";    // array of cardID or mask
  static const String groups   = "groups";   // array of cards group or mask
  static const String tags     = "tags";     // array of tags
  static const String andTags  = "andTags";  // array of tags join trough and
  static const String difficultyLevels  = "difficultyLevels";  // array of difficulty levels
  static const String exclude  = "exclude";  // bool - exclude card from studying
  static const String difficultyLevel  = "difficultyLevel"; // int, for reset difficultyLevel
  static const String style    = "style";    // body style
}

/// Card execution settings according to their difficulty
class DrfDifficulty {
  static const String level                      = "level"; // int, difficulty level, values 0 - 5

  // integer, the number of seconds earned if the answer is correct
  static const String maxCost                    = "maxCost";
  static const String minCost                    = "minCost";

  // integer, the number of penalty seconds in case of NOT correct answer
  static const String maxPenalty                 = "maxPenalty";
  static const String minPenalty                 = "minPenalty";

  // integer, the number of attempts at a solution in one approach
  static const String maxTryCount                = "maxTryCount";
  static const String minTryCount                = "minTryCount";

  // integer, seconds, the time allotted for the solution
  static const String maxDuration                = "maxDuration";
  static const String minDuration                = "minDuration";

  // integer, the lower value of the cost as a percentage of the current set cost
  static const String maxDurationLowCostPercent  = "maxDurationLowCostPercent";
  static const String minDurationLowCostPercent  = "minDurationLowCostPercent";
}

class RegOptions {
  final int hotDayCount;   // Number of days for which the statistics are calculated

  final int hotCardQualityTopLimit; // cards with lower quality are considered to be actively studied
  final int maxCountHotCard;        // Maximum number of cards in active study

  /// limits to determine the activity of the group
  final int hotGroupMinQualityTopLimit; // Minimum quality for the cards included in the group
  final int hotGroupAvgQualityTopLimit; // Average quality of the cards included in the group
  
  /// the minimum number of active study groups,
  /// If the quantity is less than the limit - the system tries to select a card from the new group
  final int minCountHotQualityGroup;

  final int lowGroupAvgQualityTopLimit; // the upper limit of average quality for begin-quality groups

  /// maximal number of begin-quality groups,
  /// If the number is equal to the limit - the system selects cards from the groups already being studied
  final int maxCountLowQualityGroup;

  /// Decrease the quality when the amount of statistics is small
  ///   if the new card has very good results from the beginning
  ///   these parameters will not let the quality grow too fast
  final int lowTryCount; // minimum number of tests
  final int lowDayCount; // minimum number of days

  /// Maximum available quality with a negative last result
  final int negativeLastResultMaxQualityLimit;

  final int minEarnTransferMinutes;

  RegOptions({
    this.hotDayCount                = 7,
    this.hotCardQualityTopLimit     = 70,
    this.maxCountHotCard            = 20,
    this.hotGroupMinQualityTopLimit = 60,
    this.hotGroupAvgQualityTopLimit = 70,
    this.minCountHotQualityGroup    = 15,
    this.lowGroupAvgQualityTopLimit = 10,
    this.maxCountLowQualityGroup    = 2,
    this.lowTryCount                = 7,
    this.lowDayCount                = 4,
    this.negativeLastResultMaxQualityLimit = 50,
    this.minEarnTransferMinutes = 10,
  });

  factory RegOptions.fromMap(Map<String, dynamic> json){
    return RegOptions(
        hotDayCount                 : json[DrfOptions.hotDayCount               ],
        hotCardQualityTopLimit      : json[DrfOptions.hotCardQualityTopLimit    ],
        maxCountHotCard             : json[DrfOptions.maxCountHotCard           ],
        hotGroupMinQualityTopLimit  : json[DrfOptions.hotGroupMinQualityTopLimit],
        hotGroupAvgQualityTopLimit  : json[DrfOptions.hotGroupAvgQualityTopLimit],
        minCountHotQualityGroup     : json[DrfOptions.minCountHotQualityGroup   ],
        lowGroupAvgQualityTopLimit  : json[DrfOptions.lowGroupAvgQualityTopLimit],
        maxCountLowQualityGroup     : json[DrfOptions.maxCountLowQualityGroup   ],
        lowTryCount                 : json[DrfOptions.lowTryCount               ],
        lowDayCount                 : json[DrfOptions.lowDayCount               ],
        minEarnTransferMinutes      : json[DrfOptions.minEarnTransferMinutes    ],
        negativeLastResultMaxQualityLimit : json[DrfOptions.negativeLastResultMaxQualityLimit],
    );
  }

  Map<String, dynamic> toJson() => {
    DrfOptions.hotDayCount                : hotDayCount,
    DrfOptions.hotCardQualityTopLimit     : hotCardQualityTopLimit,
    DrfOptions.maxCountHotCard            : maxCountHotCard,
    DrfOptions.hotGroupMinQualityTopLimit : hotGroupMinQualityTopLimit,
    DrfOptions.hotGroupAvgQualityTopLimit : hotGroupAvgQualityTopLimit,
    DrfOptions.minCountHotQualityGroup    : minCountHotQualityGroup,
    DrfOptions.lowGroupAvgQualityTopLimit : lowGroupAvgQualityTopLimit,
    DrfOptions.maxCountLowQualityGroup    : maxCountLowQualityGroup,
    DrfOptions.lowTryCount                : lowTryCount,
    DrfOptions.lowDayCount                : lowDayCount,
    DrfOptions.minEarnTransferMinutes     : minEarnTransferMinutes,
    DrfOptions.negativeLastResultMaxQualityLimit : negativeLastResultMaxQualityLimit,
  };
}

class RegCardSet {
  final String fileGUID;        // GUID of decardj file
  final List<String>? cards;    // array of cardID or mask
  final List<String>? groups;   // array of cards group or mask
  final List<String>? tags;     // array of tags
  final List<String>? andTags;  // array of tags join trough and
  final List<int>? difficultyLevels; // array of difficulty levels
  
  final bool exclude;          // bool - exclude card from studying
  final int?  difficultyLevel;  // int - difficulty level
  final Map<String, dynamic>? style; // body style

  RegCardSet({
    required this.fileGUID,
    this.cards,
    this.groups,
    this.tags,
    this.andTags,
    this.difficultyLevels,
    this.exclude = false,
    this.difficultyLevel,
    this.style
  });

  factory RegCardSet.fromMap(Map<String, dynamic> json) {
    json[DrfCardSet.cards] != null ? List<String>.from(json[DrfCardSet.cards].map((x) => x)) : [];

    return RegCardSet(
      fileGUID         : json[DrfCardSet.fileGUID],
      cards            : json[DrfCardSet.cards   ] != null ? List<String>.from(json[DrfCardSet.cards].map((x)   => x)) : [],
      groups           : json[DrfCardSet.groups  ] != null ? List<String>.from(json[DrfCardSet.groups].map((x)  => x)) : [],
      tags             : json[DrfCardSet.tags    ] != null ? List<String>.from(json[DrfCardSet.tags].map((x)    => x)) : [],
      andTags          : json[DrfCardSet.andTags ] != null ? List<String>.from(json[DrfCardSet.andTags].map((x) => x)) : [],
      difficultyLevels : json[DrfCardSet.difficultyLevels] != null ? List<int>.from(json[DrfCardSet.difficultyLevels].map((x) => x)) : [],
      
      exclude          : json[DrfCardSet.exclude]??false,
      difficultyLevel  : json[DrfCardSet.difficultyLevel],
      style            : json[DrfCardSet.style],
    );
  }

  Map<String, dynamic> toJson() => {
    DrfCardSet.fileGUID         : fileGUID,
    DrfCardSet.cards            : cards,
    DrfCardSet.groups           : groups,
    DrfCardSet.tags             : tags,
    DrfCardSet.andTags          : andTags,
    DrfCardSet.difficultyLevels : difficultyLevels,
    DrfCardSet.exclude          : exclude,
    DrfCardSet.difficultyLevel  : difficultyLevel,
    DrfCardSet.style            : style,
  };
}

class RegDifficulty {
  // int, difficulty level, values:
  //   0 - for memorization
  //   1 - very easy task
  //   2 - easy task
  //   3 - need to think
  //   4 - difficult
  //   5 - very difficult  
  final int level; 

  // integer, the number of seconds earned if the answer is correct
  final int maxCost;
  final int minCost;

  // integer, the number of penalty seconds in case of NOT correct answer
  final int maxPenalty;
  final int minPenalty;

  // integer, the number of attempts at a solution in one approach
  final int maxTryCount;
  final int minTryCount;

  // integer, seconds, the time allotted for the solution
  final int maxDuration;
  final int minDuration;

  // integer, the lower value of the cost as a percentage of the current set cost
  final int maxDurationLowCostPercent;
  final int minDurationLowCostPercent;

  RegDifficulty({
    required this.level,
    required this.maxCost,
    required this.minCost,
    required this.maxPenalty,
    required this.minPenalty,
    required this.maxTryCount,
    required this.minTryCount,
    required this.maxDuration,
    required this.minDuration,
    required this.maxDurationLowCostPercent,
    required this.minDurationLowCostPercent,
  });

  factory RegDifficulty.fromMap(Map<String, dynamic> json){
    return RegDifficulty(
      level                     : json[DrfDifficulty.level],
      maxCost                   : json[DrfDifficulty.maxCost],
      minCost                   : json[DrfDifficulty.minCost],
      maxPenalty                : json[DrfDifficulty.maxPenalty],
      minPenalty                : json[DrfDifficulty.minPenalty],
      maxTryCount               : json[DrfDifficulty.maxTryCount],
      minTryCount               : json[DrfDifficulty.minTryCount],
      maxDuration               : json[DrfDifficulty.maxDuration],
      minDuration               : json[DrfDifficulty.minDuration],
      maxDurationLowCostPercent : json[DrfDifficulty.maxDurationLowCostPercent],
      minDurationLowCostPercent : json[DrfDifficulty.minDurationLowCostPercent],
    );
  }

  Map<String, dynamic> toJson() => {
      DrfDifficulty.level                     :level,
      DrfDifficulty.maxCost                   :maxCost,
      DrfDifficulty.minCost                   :minCost,
      DrfDifficulty.maxPenalty                :maxPenalty,
      DrfDifficulty.minPenalty                :minPenalty,
      DrfDifficulty.maxTryCount               :maxTryCount,
      DrfDifficulty.minTryCount               :minTryCount,
      DrfDifficulty.maxDuration               :maxDuration,
      DrfDifficulty.minDuration               :minDuration,
      DrfDifficulty.maxDurationLowCostPercent :maxDurationLowCostPercent,
      DrfDifficulty.minDurationLowCostPercent :minDurationLowCostPercent,
  };
}

class Regulator {
  static const int maxQuality               = 100; // Maximum learning quality
  static const int completelyStudiedQuality = 99;
  static const int studyNotStartedQuality   = -1;

  static const int lowDifficultyLevel  = 0;
  static const int highDifficultyLevel = 5;

  final RegOptions options;
  final List<RegCardSet> cardSetList;
  final List<RegDifficulty> difficultyList;


  Regulator({
    required this.options,
    required this.cardSetList,
    required this.difficultyList,
  });

  void fillDifficultyLevels([bool onlyExtreme = false]) {
    // fills missing levels with default values or proportionally from neighboring levels
    
    if (!difficultyList.any((difficulty) => difficulty.level == lowDifficultyLevel)) {
      difficultyList.add(RegDifficulty(
        level                     : lowDifficultyLevel,
        maxCost                   : 60,
        minCost                   : 15,
        maxPenalty                : 90,
        minPenalty                : 0,
        maxTryCount               : 2,
        minTryCount               : 1,
        maxDuration               : 120,
        minDuration               : 7,
        maxDurationLowCostPercent : 50,
        minDurationLowCostPercent : 0,
      ));
    }
        
    if (!difficultyList.any((difficulty) => difficulty.level == highDifficultyLevel)) {
      difficultyList.add(RegDifficulty(
        level                     : highDifficultyLevel,
        maxCost                   : 900,
        minCost                   : 300,
        maxPenalty                : 700,
        minPenalty                : 30,
        maxTryCount               : 3,
        minTryCount               : 2,
        maxDuration               : 1200,
        minDuration               : 120,
        maxDurationLowCostPercent : 15,
        minDurationLowCostPercent : 15,
      ));
    }

    if (onlyExtreme) return;
    
    final absTop    = difficultyList.firstWhere((difficulty)=> difficulty.level == lowDifficultyLevel);
    final absBottom = difficultyList.firstWhere((difficulty)=> difficulty.level == highDifficultyLevel);  
        
    for (int level = lowDifficultyLevel + 1; level < highDifficultyLevel; level++) {
      if (!difficultyList.any((difficulty) => difficulty.level == level)) _addMiddleLevel(absTop, absBottom, level);
    }
  }
          
  void _addMiddleLevel(RegDifficulty absTop, RegDifficulty absBottom, int level) {
    if (difficultyList.any((difficulty) => difficulty.level == level)) return;
        
    RegDifficulty top = absTop;
    RegDifficulty bottom = absBottom;
    
    for (var difficulty in difficultyList) {
      if (difficulty.level < level && difficulty.level > top.level) {
        top = difficulty;
      }
      if (difficulty.level > level && difficulty.level < bottom.level) {
        bottom = difficulty;
      }      
    }
    
    difficultyList.add(RegDifficulty(
      level                     : level,
      maxCost                   : _proportionalValue(top.level, top.maxCost,                   bottom.level, bottom.maxCost,                   level),
      minCost                   : _proportionalValue(top.level, top.minCost,                   bottom.level, bottom.minCost,                   level),
      maxPenalty                : _proportionalValue(top.level, top.maxPenalty,                bottom.level, bottom.maxPenalty,                level),
      minPenalty                : _proportionalValue(top.level, top.minPenalty,                bottom.level, bottom.minPenalty,                level),
      maxTryCount               : _proportionalValue(top.level, top.maxTryCount,               bottom.level, bottom.maxTryCount,               level),
      minTryCount               : _proportionalValue(top.level, top.minTryCount,               bottom.level, bottom.minTryCount,               level),
      maxDuration               : _proportionalValue(top.level, top.maxDuration,               bottom.level, bottom.maxDuration,               level),
      minDuration               : _proportionalValue(top.level, top.minDuration,               bottom.level, bottom.minDuration,               level),
      maxDurationLowCostPercent : _proportionalValue(top.level, top.maxDurationLowCostPercent, bottom.level, bottom.maxDurationLowCostPercent, level),
      minDurationLowCostPercent : _proportionalValue(top.level, top.minDurationLowCostPercent, bottom.level, bottom.minDurationLowCostPercent, level),
    ));
    
  }
        
  int _proportionalValue(int topLevel, int topValue, int bottomLevel, int bottomValue, int level) {
    final z = (level - topLevel) / (bottomLevel - level);
    final int result = (( z * bottomValue + topValue ) / ( 1 + z )).round();
    return result;
  }

  RegDifficulty getDifficulty(int level){
    return difficultyList.firstWhere((difficulty) => difficulty.level == level);
  }

  factory Regulator.fromMap(Map<String, dynamic> json) {
    return Regulator(
      options : RegOptions.fromMap(json[DrfRegulator.options]),
      cardSetList : json[DrfRegulator.setList] != null ? List<RegCardSet>.from(json[DrfRegulator.setList].map((setJson) => RegCardSet.fromMap(setJson))) : [],
      difficultyList: json[DrfRegulator.difficultyList] != null ? List<RegDifficulty>.from(json[DrfRegulator.difficultyList].map((difficultyJson) => RegDifficulty.fromMap(difficultyJson))) : [],
    );
  }

  Map<String, dynamic> toJson() => {
    DrfRegulator.options        : options,
    DrfRegulator.setList        : cardSetList,
    DrfRegulator.difficultyList : difficultyList,
  };

  static Future<Regulator> fromFile(String filePath) async {
    final jsonFile = File(filePath);

    if (! await jsonFile.exists()) {
      return Regulator(options: RegOptions(), cardSetList: [], difficultyList: []);
    }

    final fileData = await jsonFile.readAsString();
    final json = jsonDecode(fileData); 
    return Regulator.fromMap(json);
  }

  Future<void> saveToFile(String filePath) async {
    final fileData = jsonEncode(this);
    final jsonFile = File(filePath);

    jsonFile.writeAsString(fileData);
  }

  Future<void> applySetListToDB(DbSource dbSource) async {
    await dbSource.tabCardHead.clearRegulatorPatchOnAllRow();

    for (int setIndex = 0; setIndex < cardSetList.length; setIndex++) {
      final setItem = cardSetList[setIndex];
      _applySetItemToDB(dbSource, setItem, setIndex);
    }
  }

  Future<void> _applySetItemToDB(DbSource dbSource, RegCardSet set, int setIndex) async {
    final jsonFileID = dbSource.tabJsonFile.fileGuidToJsonFileId(set.fileGUID);

    if (jsonFileID == null) return;

    final cardHeadRows = await dbSource.tabCardHead.getFileRows(jsonFileID: jsonFileID);

    for (var cardHeadRow in cardHeadRows) {
      final cardID    = cardHeadRow[TabCardHead.kCardID ] as int;
      final cardKey   = cardHeadRow[TabCardHead.kCardKey] as String;
      final cardGroup = cardHeadRow[TabCardHead.kGroup  ] as String;

      final cardTags = await dbSource.tabCardTag.getCardTags(jsonFileID: jsonFileID, cardID: cardID);

      if (set.cards!.isNotEmpty  && !set.cards!.contains(cardKey   )) continue;
      if (set.groups!.isNotEmpty && !set.groups!.contains(cardGroup)) continue;

      if (set.tags!.isNotEmpty) {
        var containTag = false;
        for (var tag in cardTags) {
          if (set.tags!.contains(tag)){
            containTag = true;
            break;
          }
        }
        if (!containTag) continue;
      }

      if (set.andTags!.isNotEmpty) {
        if (cardTags.isEmpty) continue;

        var containAllTag = true;
        for (var tag in set.andTags!) {
          if (!cardTags.contains(tag)){
            containAllTag = false;
            break;
          }
        }
        if (!containAllTag) continue;
      }

      await dbSource.tabCardHead.setRegulatorPatchOnCard(jsonFileID: jsonFileID, cardID: cardID, regulatorSetIndex: setIndex, exclude: set.exclude);
    }
  }

}
