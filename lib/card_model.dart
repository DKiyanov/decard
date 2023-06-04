import 'dart:ui';

import 'db.dart';
import 'decardj.dart';

typedef CardResultCallback = void Function(bool result, double earned);

class CardData {
  PacInfo   pacInfo;
  CardHead  head;
  CardBody  body;
  CardStyle style;
  CardStat  stat;

  CardResultCallback? onResult;

  late int cost;
  late int penalty;
  late int tryCount;
  late int duration;
  late int lowCost;

  bool?  _result;
  bool? get result => _result;

  double _earned = 0;
  double get earned => _earned;

  CardData({ required this.head, required this.style, required this.body, required this.stat, required this.pacInfo, this.onResult}) {
    cost     = style.maxCost     - ( (style.maxCost - style.minCost) * (100 - stat.quality) ) ~/ 100;
    tryCount = style.maxTryCount - ( (style.maxTryCount - 1) * (100 - stat.quality) ) ~/ 100;
    duration = style.maxDuration - ( (style.maxDuration - style.minDuration) * (100 - stat.quality) ) ~/ 100;
    penalty  = style.maxPenalty  - ( (style.maxPenalty - style.minPenalty) * (stat.quality) ) ~/ 100;

    lowCost = ( cost * style.lowDurationPercentCost ) ~/ 100;

    //TODO for debug
    // cost = 10;
    // lowCost = 3;
    // duration = 5;
  }

  void setResult(bool result, double earned){
    _result = result;
    _earned = earned;
    if (onResult != null) onResult!(result, earned);
  }
}

class CardPointer {
  final int jsonFileID;  // целое, идентификатор файла в БД
  final int id;          // целое идентификатор карточки

  CardPointer(this.jsonFileID, this.id);
}

enum AnswerInputMode {
  none,           // Input method not defined
  ddList,         // Drop-down list
  vList,          // vertical list
  hList,          // Horizontal list
  input,          // Arbitrary input field
  inputDigit,     // Field for arbitrary numeric input
  widgetKeyboard, // virtual keyboard: list of buttons on the keyboard, buttons can contain several characters, button separator symbol "\t" string translation "\n"
}

class CardStyle {
  final int id;                          // integer, style identifier in the database
  final int jsonFileID;                  // integer, identifier of the file in the database
  final String cardStyleKey;             // string, style identifier
  final int minCost;                     // integer, the number of minutes earned in case the answer is correct
  final int maxCost;                     // integer, the number of earned minutes in case of a correct answer
  final int minPenalty;                  // integer, the number of penalty minutes in case of incorrect answer
  final int maxPenalty;                  // integer, the number of penalty minutes in case of incorrect answer
  final int maxTryCount;                 // integer, the number of attempts for one attempt
  final int minDuration;                 // integer, the number of seconds, the time given for the solution, optional
  final int maxDuration;                 // integer, seconds, time allowed for solving, default 1
  final int lowDurationPercentCost;      // integer, the lower value of the cost as a percentage of the current set cost, the cost decreases proportionally to the time, default 100
  final bool dontShowAnswer;             // boolean, default false, will NOT show if the answer is wrong
  final List<String> answerVariantList;  // list of answer choices
  final int answerVariantCount;          // the number of displayed answer variants
  final TextAlign answerVariantAlign;    // the text alignment when displaying the answer choices
  final bool answerVariantListRandomize; // boolean, default false, output the list in random order
  final bool answerVariantMultiSel;      // boolean, default false, multiple selection from a set of values
  final AnswerInputMode answerInputMode; // string, fixed value set
  final bool answerCaseSensitive;        // boolean, answer is case sensitive
  final String? widgetKeyboard;          // virtual keyboard: list of buttons on the keyboard, buttons can contain several characters, button separator symbol "\t" string translation "\n"
  final int imageMaxHeight;              // maximum image height as a percentage of the screen height
  final int buttonImageWidth;            // Maximum button image width  as a percentage of the screen width
  final int buttonImageHeight;           // Maximum button image height as a percentage of the screen height

  const CardStyle({
    required this.id,
    required this.jsonFileID,
    required this.cardStyleKey,
    this.minCost = 0,
    required this.maxCost,
    this.minPenalty = 0,
    required this.maxPenalty,
    this.maxTryCount = 1,
    this.minDuration = 0,
    this.maxDuration = 0,
    this.lowDurationPercentCost = 100,
    this.dontShowAnswer = false,
    required this.answerVariantList,
    this.answerVariantCount = -1,
    this.answerVariantAlign = TextAlign.center,
    this.answerVariantListRandomize = false,
    this.answerVariantMultiSel = false,
    this.answerInputMode = AnswerInputMode.vList,
    this.answerCaseSensitive = false,
    this.widgetKeyboard,
    this.imageMaxHeight = 50,
    this.buttonImageWidth = 0,
    this.buttonImageHeight = 0,
  });

  factory CardStyle.fromMap(Map<String, dynamic> json){
    final String answerInputModeStr = json[DjfCardStyle.answerInputMode];
    final String textAlignStr       = json[DjfCardStyle.answerVariantAlign]??TextAlign.center.name;

    return CardStyle(
      id                         : json[TabCardStyle.kID],
      jsonFileID                 : json[TabCardStyle.kJsonFileID],
      cardStyleKey               : json[TabCardStyle.kCardStyleKey],
      minCost                    : json[DjfCardStyle.minCost]??0,
      maxCost                    : json[DjfCardStyle.maxCost],
      minPenalty                 : json[DjfCardStyle.minPenalty]??0,
      maxPenalty                 : json[DjfCardStyle.maxPenalty],
      maxTryCount                : json[DjfCardStyle.maxTryCount]??1,
      minDuration                : json[DjfCardStyle.minDuration]??0,
      maxDuration                : json[DjfCardStyle.maxDuration]??0,
      lowDurationPercentCost     : json[DjfCardStyle.lowDurationPercentCost]??100,
      dontShowAnswer             : json[DjfCardStyle.dontShowAnswer]??false,
      answerVariantList          : json[DjfCardStyle.answerVariantList] != null ? List<String>.from(json[DjfCardStyle.answerVariantList].map((x) => x)) : [],
      answerVariantCount         : json[DjfCardStyle.answerVariantCount]??-1,
      answerVariantAlign         : TextAlign.values.firstWhere((x) => x.name == textAlignStr),
      answerVariantListRandomize : json[DjfCardStyle.answerVariantListRandomize]??false,
      answerVariantMultiSel      : json[DjfCardStyle.answerVariantMultiSel]??false,
      answerInputMode            : AnswerInputMode.values.firstWhere((x) => x.name == answerInputModeStr),
      answerCaseSensitive        : json[DjfCardStyle.answerCaseSensitive]??false,
      widgetKeyboard             : json[DjfCardStyle.widgetKeyboard],
      imageMaxHeight             : json[DjfCardStyle.imageMaxHeight]??50,
      buttonImageWidth           : json[DjfCardStyle.buttonImageWidth]??0,
      buttonImageHeight          : json[DjfCardStyle.buttonImageHeight]??0,
    );
  }
}

class CardHead {
  final int    cardID;      // целое, идентификатор карточки в БД
  final int    jsonFileID;  // целое, идентификатор файла в БД
  final String cardKey;     // строка, идентификатор карточки в файле
  final String group;
  final String title;
  final int    bodyCount;

  const CardHead({
    required this.cardID,
    required this.jsonFileID,
    required this.cardKey,
    required this.group,
    required this.title,
    required this.bodyCount,
  });

  factory CardHead.fromMap(Map<String, dynamic> json) {
    return CardHead(
      cardID     : json[TabCardHead.kCardID],
      jsonFileID : json[TabCardHead.kJsonFileID],
      cardKey    : json[TabCardHead.kCardKey],
      group      : json[TabCardHead.kGroup],
      title      : json[TabCardHead.kTitle],
      bodyCount  : json[TabCardHead.kBodyCount],
    );
  }
}

class QuestionData {
  QuestionData({
    this.text,
    this.html,
    this.webUrl,
    this.audio,
    this.video,
    this.image,
    this.imgqt,
    this.app,
  });

  final String? text;   // строка, текст вопроса
  final String? html;   // строка, html с вопросом
  final String? webUrl; // ссылка на ресурс для отображения в браузере
  final String? audio;  // ссылка на audio ресурс
  final String? video;  // ссылка на video ресурс
  final String? image;  // ссылка на image
  final QuestionDataImgQt? imgqt;  // json структура см. ниже
  final QuestionDataApp? app; // json структура см. ниже

  factory QuestionData.fromMap(Map<String, dynamic> json) => QuestionData(
    text   : json["text"],
    html   : json["html"],
    webUrl : json["webURL"],
    audio  : json["audio"],
    video  : json["video"],
    image  : json["image"],
    imgqt  : json["imgqt"] != null ? QuestionDataImgQt.fromMap(json["imgqt"]) : null,
    app    : json["app"] != null ? QuestionDataApp.fromMap(json["app"]) : null,
  );
}

class QuestionDataApp {
  QuestionDataApp({
    required this.packageName,
    this.message,
  });

  final String packageName;
  final String? message;

  factory QuestionDataApp.fromMap(Map<String, dynamic> json) => QuestionDataApp(
    packageName : json["packageName"],
    message     : json["message"],
  );
}

class QuestionDataImgQt {
  QuestionDataImgQt({
    required this.image,
    required this.mask,
    this.answers,
  });

  final String image;
  final String mask;
  final List<String>? answers;

  factory QuestionDataImgQt.fromMap(Map<String, dynamic> json) => QuestionDataImgQt(
    image   : json["image"],
    mask    : json["mask"],
    answers : List<String>.from(json["answers"].map((x) => x)),
  );
}

class CardBody {
  final int    id;                // целое, идентификатор стиля в БД
  final int    jsonFileID;        // целое, идентификатор файла в БД
  final int    cardID;            // целое, идентификатор карточки
  final int    bodyNum;           // целое,
  final QuestionData questionData;
  final List<String> styleKeyList; // Список глобальных стилей
  final Map<String, dynamic> styleMap; // Собственный стль тела
  final List<String> answerList;

  const CardBody({
    required this.id,
    required this.jsonFileID,
    required this.cardID,
    required this.bodyNum,
    required this.questionData,
    required this.styleKeyList,
    required this.styleMap,
    required this.answerList
  });

  factory CardBody.fromMap(Map<String, dynamic> json){
    return CardBody(
      id                : json[TabCardBody.kID],
      jsonFileID        : json[TabCardBody.kJsonFileID],
      cardID            : json[TabCardBody.kCardID],
      bodyNum           : json[TabCardBody.kBodyNum],
      questionData      : QuestionData.fromMap(json['questionData']),
      styleKeyList      : json["styleIdList"] != null ? List<String>.from(json["styleIdList"].map((x) => x)) : [],
      styleMap          : json['style']??{},
      answerList        : List<String>.from(json["answerList"].map((x) => x)),
    );
  }
}

class CardStat {
  final int    id;                // целое,   идентификатор стиля в БД
  final int    jsonFileID;        // целое,   идентификатор файла в БД
  final int    cardID;            // целое,  идентификатор карточки в БД
  final String cardKey;           // строка,  идентификатор карточки
  final String cardGroupKey;      // строка,  идентификатор группы карточек
  final int    quality;           // качество изучения, 1 - картичка полностью изучена; 100 - минимальная степень изученности
  final int    qualityFromDate;   // первая дата учтённая при расчёте quality
  final int    startDate;         // дата начала изучения
  final int    lastTestDate;      // дата последнего изучения
  final int    testsCount;        // количество предъявления
  final String json;              // данные статистики карточки хранятся как json, когда понадобится распаковываются используются для расчёта quality и обновляются

  CardStat({
    required this.id,
    required this.jsonFileID,
    required this.cardID,
    required this.cardKey,
    required this.cardGroupKey,
    required this.quality,
    required this.qualityFromDate,
    required this.startDate,
    required this.lastTestDate,
    required this.testsCount,
    required this.json
  });

  factory CardStat.fromMap(Map<String, dynamic> json){
    return CardStat(
      id                : json[TabCardStat.kID],
      jsonFileID        : json[TabCardStat.kJsonFileID],
      cardID            : json[TabCardStat.kCardID],
      cardKey           : json[TabCardStat.kCardKey],
      cardGroupKey      : json[TabCardStat.kCardGroupKey],
      quality           : json[TabCardStat.kQuality],
      qualityFromDate   : json[TabCardStat.kQualityFromDate],
      startDate         : json[TabCardStat.kStartDate],
      lastTestDate      : json[TabCardStat.kLastTestDate]??0,
      testsCount        : json[TabCardStat.kTestsCount],
      json              : json[TabCardStat.kJson],
    );
  }
}

class PacInfo {
  final int    jsonFileID;
  final String path;
  final String filename;
  final String title;
  final String guid;
  final int    version;
  final String author;
  final String site;
  final String email;
  final String license;

  PacInfo({
    required this.jsonFileID,
    required this.path,
    required this.filename,
    required this.title,
    required this.guid,
    required this.version,
    required this.author,
    required this.site,
    required this.email,
    required this.license,
  });

  factory PacInfo.fromMap(Map<String, dynamic> json){
    return PacInfo(
      jsonFileID : json[TabJsonFile.kJsonFileID],
      path       : json[TabJsonFile.kPath],
      filename   : json[TabJsonFile.kFilename],
      title      : json[TabJsonFile.kTitle],
      guid       : json[TabJsonFile.kGuid],
      version    : json[TabJsonFile.kVersion],
      author     : json[TabJsonFile.kAuthor],
      site       : json[TabJsonFile.kSite],
      email      : json[TabJsonFile.kEmail],
      license    : json[TabJsonFile.kLicense],
    );
  }
}