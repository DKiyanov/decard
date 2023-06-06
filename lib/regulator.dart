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

class Regulator {
  static const String kOptions = "options";
  static const String kSetList = "setList";

  final RegOptions options;
  final List<RegSet> setList;

  Regulator({
    required this.options,
    required this.setList,
  });

  factory Regulator.fromMap(Map<String, dynamic> json) {
    return Regulator(
      options : RegOptions.fromMap(json[kOptions]),
      setList : json[kSetList] != null ? List<RegSet>.from(json[kSetList].map((setJson) => RegSet.fromMap(setJson))) : [],
    );
  }

  static Future<Regulator> fromFile(String filePath) async {
    final jsonFile = File(filePath);

    if (! await jsonFile.exists()) {
      return Regulator(options: RegOptions(), setList: []);
    }

    final fileData = await jsonFile.readAsString();
    final json = jsonDecode(fileData); 
    return Regulator.fromMap(json);
  }
}
