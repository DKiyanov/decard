class DrfOptions {
  static const String hotDayCount = "hotDayCount";   // Количество дней для которых расчитывается стстистика

  static const String hotCardQualityTopLimit = "hotCardQualityTopLimit"; // карточки с меньшим качеством считаются активно изучаемыми
  static const String maxCountHotCard = "maxCountHotCard";        // Максимальное кол-во карточек в активном изучении

  /// лимиты для определения активности группы
  static const String hotGroupMinQualityTopLimit = "hotGroupMinQualityTopLimit"; // Минимальное качество по карточам входящим в группу
  static const String hotGroupAvgQualityTopLimit = "hotGroupAvgQualityTopLimit"; // Среднее качество по карточкам входящим в группу

  /// минимальое кол-во активно изучаемых групп,
  /// если кол-во меньше лимита - система пытается выбрать карточку из новой группы
  static const String minCountHotQualityGroup = "minCountHotQualityGroup";

  static const String lowGroupAvgQualityTopLimit = "lowGroupAvgQualityTopLimit"; // Среднее качество по карточкам входящим в группу

  /// мксимальное кол-во групп в начальной стадии изучения,
  /// если кол-во роавно лимиту - система выбирает карточки из уже изучаемых групп
  static const String maxCountLowQualityGroup = "maxCountLowQualityGroup";

  /// понижение качества при малом объёме статистики
  ///   если по новой карточке с самого начала будут очень хорошие результаты
  ///   эти пареметры не дадут рости качеству слшком быстро
  static const String lowTryCount = "lowTryCount"; // минимальное кол-во тестов
  static const String lowDayCount = "lowDayCount"; // минимальное кол-во дней
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
  final int hotDayCount;   // Количество дней для которых расчитывается стстистика

  final int hotCardQualityTopLimit; // карточки с меньшим качеством считаются активно изучаемыми
  final int maxCountHotCard;        // Максимальное кол-во карточек в активном изучении

  /// лимиты для определения активности группы
  final int hotGroupMinQualityTopLimit; // Минимальное качество по карточам входящим в группу
  final int hotGroupAvgQualityTopLimit; // Среднее качество по карточкам входящим в группу

  /// минимальое кол-во активно изучаемых групп,
  /// если кол-во меньше лимита - система пытается выбрать карточку из новой группы
  final int minCountHotQualityGroup;

  final int lowGroupAvgQualityTopLimit; // Среднее качество по карточкам входящим в группу

  /// мксимальное кол-во групп в начальной стадии изучения,
  /// если кол-во роавно лимиту - система выбирает карточки из уже изучаемых групп
  final int maxCountLowQualityGroup;

  /// понижение качества при малом объёме статистики
  ///   если по новой карточке с самого начала будут очень хорошие результаты
  ///   эти пареметры не дадут рости качеству слшком быстро
  final int lowTryCount; // минимальное кол-во тестов
  final int lowDayCount; // минимальное кол-во дней

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

}