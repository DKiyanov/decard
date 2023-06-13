import 'dart:io';
import 'dart:convert';

class DrfOptions {
  static const String hotDayCount = "hotDayCount";   // Number of days for which the stastistics are calculated

  static const String hotCardQualityTopLimit = "hotCardQualityTopLimit"; // cards with lower quality are considered to be actively studied
  static const String maxCountHotCard = "maxCountHotCard";        // Maximum number of cards in active study

  /// limits to determine the activity of the group
  static const String hotGroupMinQualityTopLimit = "hotGroupMinQualityTopLimit"; // Minimum quality for the cards included in the group
  static const String hotGroupAvgQualityTopLimit = "hotGroupAvgQualityTopLimit"; // Average quality of the cards included in the group

  /// the minimum number of active study groups,
  /// If the quantity is less than the limit - the system tries to select a card from the new group
  static const String minCountHotQualityGroup = "minCountHotQualityGroup";

  static const String lowGroupAvgQualityTopLimit = "lowGroupAvgQualityTopLimit"; // 

  /// maximal number of groups in the beginer stage of the study,
  /// If the number is equal to the limit - the system selects cards from the groups already being studied
  static const String maxCountLowQualityGroup = "maxCountLowQualityGroup";

  /// Decrease the quality when the amount of statistics is small
  ///   if the new card has very good results from the beginning
  ///   these parameters will not let the quality grow too fast
  static const String lowTryCount = "lowTryCount"; // minimum number of tests
  static const String lowDayCount = "lowDayCount"; // Minimum number of days

  /// Maximum available quality with a negative last result
  static const String negativeLastResultMaxQualityLimit = "negativeLastResultMaxQualityLimit";

  /// minimum earnings that can be transferred outside
  static const String minEarnTransferValue = 'minEarnTransferVal';
}

class DrfSet {
  static const String fileGUID = "fileGUID"; // GUID of decardj file
  static const String cards    = "cards";    // array of cardID or mask
  static const String groups   = "groups";   // array of cards group or mask
  static const String tags     = "tags";     // array of tags
  static const String andTags  = "andTags";  // array of tags join trough and
  static const String exclude  = "exclude";  // bool - exclude card from studying
  static const String style    = "style";    // body style
}

class DrfDifficulty {
  static const String id                         = "id";                         // int, difficulty ID, values 0 - 5

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
  final int hotDayCount;   // Number of days for which the stastistics are calculated

  final int hotCardQualityTopLimit; // cards with lower quality are considered to be actively studied
  final int maxCountHotCard;        // Maximum number of cards in active study

  /// limits to determine the activity of the group
  final int hotGroupMinQualityTopLimit; // Minimum quality for the cards included in the group
  final int hotGroupAvgQualityTopLimit; // Average quality of the cards included in the group
  
  /// the minimum number of active study groups,
  /// If the quantity is less than the limit - the system tries to select a card from the new group
  final int minCountHotQualityGroup;

  final int lowGroupAvgQualityTopLimit; // the upper limit of average quality for beginer-quality groups

  /// maximal number of beginer-quality groups,
  /// If the number is equal to the limit - the system selects cards from the groups already being studied
  final int maxCountLowQualityGroup;

  /// Decrease the quality when the amount of statistics is small
  ///   if the new card has very good results from the beginning
  ///   these parameters will not let the quality grow too fast
  final int lowTryCount; // minimum number of tests
  final int lowDayCount; // minimum number of days

  /// Maximum available quality with a negative last result
  final int negativeLastResultMaxQualityLimit;

  final int minEarnTransferValue;

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
    this.minEarnTransferValue = 10,
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
        negativeLastResultMaxQualityLimit : json[DrfOptions.negativeLastResultMaxQualityLimit],
        minEarnTransferValue        : json[DrfOptions.minEarnTransferValue],
    );
  }
}

class RegSet {
  final String fileGUID;        // GUID of decardj file
  final List<String>? cards;    // array of cardID or mask
  final List<String>? groups;   // array of cards group or mask
  final List<String>? tags;     // array of tags
  final List<String>? andTags;  // array of tags join trough and
  final bool exclude;           // bool - exclude card from studying
  final Map<String, dynamic>? style; // body style

  RegSet({
    required this.fileGUID,
    this.cards,
    this.groups,
    this.tags,
    this.andTags,
    this.exclude = false,
    this.style
  });

  factory RegSet.fromMap(Map<String, dynamic> json){
    json[DrfSet.cards] != null ? List<String>.from(json[DrfSet.cards].map((x) => x)) : [];

    return RegSet(
      fileGUID : json[DrfSet.fileGUID],
      cards    : json[DrfSet.cards]   != null ? List<String>.from(json[DrfSet.cards].map((x)   => x)) : [],
      groups   : json[DrfSet.groups]  != null ? List<String>.from(json[DrfSet.groups].map((x)  => x)) : [],
      tags     : json[DrfSet.tags]    != null ? List<String>.from(json[DrfSet.tags].map((x)    => x)) : [],
      andTags  : json[DrfSet.andTags] != null ? List<String>.from(json[DrfSet.andTags].map((x) => x)) : [],
      exclude  : json[DrfSet.exclude],
      style    : json[DrfSet.style],
    );
  }
}

class RegDifficulty {
  final int id; // int, difficulty ID, values 0 - 5

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
    required this.id,
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
      id                        : json[DrfDifficulty.id],
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
}

class Regulator {
  static const String kOptions = "options";
  static const String kSetList = "setList";
  static const String kDifficultyList = "difficultyList";

  final RegOptions options;
  final List<RegSet> setList;
  final List<RegDifficulty> difficultyList;

  Regulator({
    required this.options,
    required this.setList,
    required this.difficultyList,
  });

  factory Regulator.fromMap(Map<String, dynamic> json) {
    return Regulator(
      options : RegOptions.fromMap(json[kOptions]),
      setList : json[kSetList] != null ? List<RegSet>.from(json[kSetList].map((setJson) => RegSet.fromMap(setJson))) : [],
      difficultyList: json[kDifficultyList] != null ? List<RegDifficulty>.from(json[kDifficultyList].map((setJson) => RegDifficulty.fromMap(setJson))) : [],
    );
  }

  static Future<Regulator> fromFile(String filePath) async {
    final jsonFile = File(filePath);

    if (! await jsonFile.exists()) {
      return Regulator(options: RegOptions(), setList: [], difficultyList: []);
    }

    final fileData = await jsonFile.readAsString();
    final json = jsonDecode(fileData); 
    return Regulator.fromMap(json);
  }
}
