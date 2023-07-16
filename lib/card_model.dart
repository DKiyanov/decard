import 'dart:math';
import 'dart:ui';

import 'child.dart';
import 'db.dart';
import 'decardj.dart';
import 'regulator.dart';

typedef CardResultCallback = void Function(bool result, double earned);

class CardData {
  PacInfo   pacInfo;
  CardHead  head;
  CardBody  body;
  CardStyle style;
  CardStat  stat;

  RegDifficulty difficulty;

  List<String>? tagList;

  CardResultCallback? onResult;

  late int cost;
  late int penalty;
  late int tryCount;
  late int duration;
  late int lowCost;

  RegCardSet?  regSet;

  bool?  _result;
  bool? get result => _result;

  double _earned = 0;
  double get earned => _earned;

  bool get exclude => regSet != null && regSet!.exclude;

  CardData({
    required this.head,
    required this.style,
    required this.body,
    required this.stat,
    required this.pacInfo,
    required this.difficulty,
    this.regSet,
    this.tagList,
    this.onResult
  }) {
    cost     = _getValueForQuality(difficulty.maxCost,     difficulty.minCost,     stat.quality);
    penalty  = _getValueForQuality(difficulty.minPenalty,  difficulty.maxPenalty,  stat.quality); // penalty moves in the opposite direction to all others
    tryCount = _getValueForQuality(difficulty.maxTryCount, difficulty.minTryCount, stat.quality);
    duration = _getValueForQuality(difficulty.maxDuration, difficulty.minDuration, stat.quality);

    lowCost = (cost * _getValueForQuality(difficulty.maxDurationLowCostPercent, difficulty.minDurationLowCostPercent, stat.quality) / 100).round();
  }

  int _getValueForQuality(int maxValue, int minValue, int quality){
    final int result = (maxValue - (( (maxValue - minValue) * quality ) / 100 ) ).round();
    return result;
  }

  void setResult(bool result, double earned){
    _result = result;
    _earned = earned;
    if (onResult != null) onResult!.call(result, earned);
  }

  static Future<CardData> create(
      Child child,
      int jsonFileID,
      int cardID,
      {
        int? bodyNum,
        CardSetBody setBody = CardSetBody.random,
        bool tags = false,
        CardResultCallback? onResult
      }) async {

    final card = await _CardGenerator.createCard(child, jsonFileID, cardID, bodyNum: bodyNum, setBody: setBody, tags: tags, onResult: onResult);
    return card;
  }

}

enum CardSetBody {
  none,
  first,
  last,
  random,
}

class _CardGenerator {
  static Child?     _child;

  static CardHead?  _cardHead;
  static CardBody?  _cardBody;
  static CardStyle? _cardStyle;

  static RegCardSet?    _regSet;

  static final _random = Random();

  static Future<CardData> createCard(
      Child child,
      int jsonFileID,
      int cardID,
      {
        int? bodyNum,
        CardSetBody setBody = CardSetBody.random,
        bool tags = false,
        CardResultCallback? onResult
      }) async {

    _child     = child;
    _cardHead  = null;
    _cardBody  = null;
    _cardStyle = null;
    _regSet    = null;

    final headData = await child.dbSource.tabCardHead.getRow(cardID);
    _cardHead = CardHead.fromMap(headData!);

    if (_cardHead!.regulatorSetIndex != null) {
      _regSet = child.regulator.cardSetList[_cardHead!.regulatorSetIndex!];
    }

    if (bodyNum != null) {
      await _setBodyNum(bodyNum);
    } else {
      switch(setBody){
        case  CardSetBody.first:
          await _setBodyNum(0);
          break;
        case CardSetBody.last:
          await _setBodyNum(_cardHead!.bodyCount - 1);
          break;
        case CardSetBody.random:
          await _setRandomBodyNum();
          break;
        case CardSetBody.none:
          break;
      }
    }

    final statData = await child.dbSource.tabCardStat.getRow(cardID);
    final cardStat = CardStat.fromMap(statData!);

    final pacData = await child.dbSource.tabJsonFile.getRow(jsonFileID: jsonFileID);
    final pacInfo = PacInfo.fromMap(pacData!);

    RegDifficulty? difficulty;
    if (_regSet != null && _regSet!.difficultyLevel != null) {
      difficulty = child.regulator.getDifficulty(_regSet!.difficultyLevel!);
    } else {
      difficulty = child.regulator.getDifficulty(_cardHead!.difficulty);
    }

    List<String>? tagList;

    if (tags) {
      tagList = await child.dbSource.tabCardTag.getCardTags(jsonFileID: _cardHead!.jsonFileID, cardID: _cardHead!.cardID);
      tagList.add('${DjfUpLink.cardTagPrefix}${_cardHead!.cardKey}');
      if (_cardHead!.group.isNotEmpty){
        tagList.add('${DjfUpLink.groupTagPrefix}${_cardHead!.group}');
      }
    }

    final card = CardData(
        head       : _cardHead!,
        body       : _cardBody!,
        style      : _cardStyle!,
        stat       : cardStat,
        pacInfo    : pacInfo,
        difficulty : difficulty,
        regSet     : _regSet,
        tagList    : tagList,
        onResult   : onResult,
    );

    return card;
  }

  static Future<void> _setBodyNum(int bodyNum) async {
    final bodyData = await _child!.dbSource.tabCardBody.getRow(jsonFileID: _cardHead!.jsonFileID, cardID: _cardHead!.cardID, bodyNum: bodyNum);
    _cardBody = CardBody.fromMap(bodyData!);

    final Map<String, dynamic> styleMap = {};
    for (var styleKey in _cardBody!.styleKeyList) {
      final styleData = await _child!.dbSource.tabCardStyle.getRow(jsonFileID: _cardHead!.jsonFileID, cardStyleKey: styleKey );
      styleMap.addEntries(styleData!.entries.where((element) => element.value != null));
    }

    styleMap.addEntries(_cardBody!.styleMap.entries.where((element) => element.value != null));

    if (_regSet != null && _regSet!.style != null) {
      styleMap.addEntries(_regSet!.style!.entries.where((element) => element.value != null));
    }

    _cardStyle = CardStyle.fromMap(styleMap);
  }

  static Future<void> _setRandomBodyNum() async {
    int bodyNum = 0;
    if (_cardHead!.bodyCount > 1) bodyNum = _random.nextInt(_cardHead!.bodyCount);

    await _setBodyNum(bodyNum);
  }
}

class CardPointer {
  final int jsonFileID;  // integer, identifier of the file in the database
  final int cardID;      // integer card identifier in the database

  CardPointer(this.jsonFileID, this.cardID);
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
  final int    cardID;      // integer, the card identifier in the database
  final int    jsonFileID;  // integer, identifier of the file in the database
  final String cardKey;     // string, identifier of the card in the file
  final String group;
  final String title;
  final int    difficulty;
  final int    bodyCount;

  final int?    regulatorSetIndex;

  const CardHead({
    required this.cardID,
    required this.jsonFileID,
    required this.cardKey,
    required this.group,
    required this.title,
    required this.difficulty,
    required this.bodyCount,
    required this.regulatorSetIndex
  });

  factory CardHead.fromMap(Map<String, dynamic> json) {
    return CardHead(
      cardID     : json[TabCardHead.kCardID],
      jsonFileID : json[TabCardHead.kJsonFileID],
      cardKey    : json[TabCardHead.kCardKey],
      group      : json[TabCardHead.kGroup],
      title      : json[TabCardHead.kTitle],
      difficulty : json[TabCardHead.kDifficulty]??0,
      bodyCount  : json[TabCardHead.kBodyCount],
      regulatorSetIndex : json[TabCardHead.kRegulatorSetIndex],
    );
  }
}

class QuestionData {
  QuestionData({
    this.text,
    this.html,
    this.markdown,
    this.audio,
    this.video,
    this.image,
  });

  final String? text;     // String question text
  final String? html;     // link to html source
  final String? markdown; // link to markdown source
  final String? audio;    // link to audio source
  final String? video;    // link to video source
  final String? image;    // link to image source

  factory QuestionData.fromMap(Map<String, dynamic> json) => QuestionData(
    text     : json[DjfQuestionData.text],
    html     : json[DjfQuestionData.html],
    markdown : json[DjfQuestionData.markdown],
    audio    : json[DjfQuestionData.audio],
    video    : json[DjfQuestionData.video],
    image    : json[DjfQuestionData.image],
  );
}

class CardBody {
  final int    id;                // integer, body identifier in the database
  final int    jsonFileID;        // integer, file identifier in the database
  final int    cardID;            // integer, card identifier in the database
  final int    bodyNum;           // integer, body number
  final QuestionData questionData;
  final List<String> styleKeyList; // List of global styles
  final Map<String, dynamic> styleMap; // Own body style
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
      questionData      : QuestionData.fromMap(json[ DjfCardBody.questionData]),
      styleKeyList      : json[ DjfCardBody.styleIdList] != null ? List<String>.from(json[ DjfCardBody.styleIdList].map((x) => x)) : [],
      styleMap          : json[ DjfCardBody.style]??{},
      answerList        : List<String>.from(json[ DjfCardBody.answerList].map((x) => x)),
    );
  }
}

class CardStat {
  final int    id;                // integer, stat identifier in the database
  final int    jsonFileID;        // integer, file identifier in the database
  final int    cardID;            // integer, card identifier in the database
  final String cardKey;           // string, card identifier in the file
  final String cardGroupKey;      // string, card group identifier
  final int    quality;           // studying quality, 100 - card is completely studied; 0 - minimum studying quality
  final int    qualityFromDate;   // the first date taken into account when calculating quality
  final int    startDate;         // date of studying beginning
  final int    lastTestDate;      // date of last test
  final int    testsCount;        // number of tests
  final String json;              // card statistics data are stored as json, when needed they are unpacked and used for quality calculation and updated

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
  final int    sourceFileID;
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
    required this.sourceFileID,
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
      jsonFileID   : json[TabJsonFile.kJsonFileID],
      sourceFileID : json[TabJsonFile.kSourceFileID],
      path         : json[TabJsonFile.kPath],
      filename     : json[TabJsonFile.kFilename],
      title        : json[TabJsonFile.kTitle],
      guid         : json[TabJsonFile.kGuid],
      version      : json[TabJsonFile.kVersion],
      author       : json[TabJsonFile.kAuthor],
      site         : json[TabJsonFile.kSite],
      email        : json[TabJsonFile.kEmail],
      license      : json[TabJsonFile.kLicense],
    );
  }
}