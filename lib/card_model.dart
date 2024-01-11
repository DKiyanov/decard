import 'dart:math';
import 'dart:ui';
import 'regulator.dart';
import 'package:path/path.dart' as path_util;

import 'db.dart';
import 'decardj.dart';
import 'media_widgets.dart';

class CardParam {
  final RegDifficulty difficulty;
  final int quality;

  late int cost;
  late int penalty;
  late int tryCount;
  late int duration;
  late int lowCost;

  bool noSaveResult = false;

  CardParam(this.difficulty, this.quality) {
    cost     = _getValueForQuality(difficulty.maxCost,     difficulty.minCost,     quality);
    penalty  = _getValueForQuality(difficulty.minPenalty,  difficulty.maxPenalty,  quality); // penalty moves in the opposite direction to all others
    tryCount = _getValueForQuality(difficulty.maxTryCount, difficulty.minTryCount, quality);
    duration = _getValueForQuality(difficulty.maxDuration, difficulty.minDuration, quality);

    lowCost = (cost * _getValueForQuality(difficulty.maxDurationLowCostPercent, difficulty.minDurationLowCostPercent, quality) / 100).round();
  }

  int _getValueForQuality(int maxValue, int minValue, int quality){
    final int result = (maxValue - (( (maxValue - minValue) * quality ) / 100 ) ).round();
    return result;
  }
}

class TagPrefix {
  static String cardKey    = 'id@';
  static String group      = 'grp@';
  static String difficulty = 'dfy@';
}

class CardSource {
  String? _type;
  String? _data;

  String get type => _type!;
  String get data => _data!;
  String get source => '$_type:$_data';

  CardSource(String source) {
    _type = FileExt.getContentExt(source);
    _data = FileExt.getContentData(_type!, source);

    if (_type!.isNotEmpty) return;

    final fileExt = FileExt.getFileExt(source);
    _type = FileExt.contentUnknown;

    if (fileExt.isNotEmpty) {
      if (FileExt.imageExtList.contains(fileExt)) {
        _type = FileExt.contentImage;
      }
      if (FileExt.audioExtList.contains(fileExt)) {
        _type = FileExt.contentAudio;
      }
      if (FileExt.videoExtList.contains(fileExt)) {
        _type = FileExt.contentVideo;
      }

      if (FileExt.txtExtList.contains(fileExt)) {
        _type = fileExt;
      }
    }
  }
}

class FileExt {
  static const String textFile = "text:";
  static const txtExtList    = <String>['txt', 'md', 'html'];
  static const imageExtList  = <String>['apng', 'avif', 'gif', 'jpg', 'jpeg', 'jfif', 'pjpeg', 'pjp', 'png', 'svg', 'webp', 'bmp', 'tif', 'tiff'];
  static const audioExtList  = <String>['m4a', 'flac', 'mp3', 'mp4', 'wav', 'wma', 'aac'];
  static const videoExtList  = <String>['mp4'];
  static const sourceExtList = <String>[...txtExtList, ...imageExtList, ...audioExtList, ...videoExtList];

  static const contentUnknown  = 'unknown';
  static const contentImage    = 'image';
  static const contentAudio    = 'audio';
  static const contentVideo    = 'video';
  static const contentHtml     = 'html';
  static const contentMarkdown = 'md';
  static const contentTextConstructor = 'decardtc';
  static const contentTxt      = 'txt'; // text file
  static const contentText     = 'text'; // text in field
  static const contentValues    = <String>[contentImage, contentAudio, contentVideo, contentHtml, contentMarkdown, contentTxt, contentText];
  static const contentTextFiles = <String>[contentHtml, contentMarkdown, contentTxt, contentTextConstructor];

  static String getFileExt(String fileName) {
    final fileExt = path_util.extension(fileName);
    if (fileExt.isEmpty) return '';
    if (fileExt.length > 6) return '';

    final extension = fileExt.toLowerCase().substring(1);

    if (!sourceExtList.contains(extension)) {
      return '';
    }

    return extension;
  }

  static String getContentExt(String content) {
    String subStr = '';
    if (content.length > 10) {
      subStr = content.substring(0, 10);
    } else {
      subStr = content;
    }

    if (subStr.contains(':')){
      final contentExt = subStr.split(':').first.toLowerCase();
      if (contentValues.contains(contentExt)) return contentExt;
    }

    return '';
  }

  static String getContentType(String content) {
    final contentExt = getContentExt(content);
    if (contentExt.isNotEmpty) {
      if (contentValues.contains(contentExt)) {
        return contentExt;
      }
      return contentUnknown;
    }

    final fileExt = getFileExt(content);

    if (fileExt.isEmpty) return contentUnknown;


    if (imageExtList.contains(fileExt)) {
      return contentImage;
    }
    if (audioExtList.contains(fileExt)) {
      return contentAudio;
    }
    if (videoExtList.contains(fileExt)) {
      return contentVideo;
    }
    if (txtExtList.contains(fileExt)) {
      return fileExt;
    }

    return contentUnknown;
  }

  static String getContentData(String contentExt, String content) {
    if (contentExt.isEmpty) return content;
    return content.substring(contentExt.length + 1);
  }

  static String prepareMarkdown(CardData card, String markdown) {
    final regexp = RegExp(r'!\[.*\]\((.*?)\s*(".*")?\s*\)', caseSensitive: false, multiLine: true);

    final newMarkdown = markdown.replaceAllMapped(regexp, (match) {
      final matchStr = match[0]!;
      final fileName = match[1];
      if (fileName == null) return matchStr;

      final fileUrl = getFileUrl(card, fileName)??fileName;
      final str = matchStr.replaceFirst(']($fileName', ']($fileUrl');
      return str;
    });

    return newMarkdown;
  }

  static String prepareHtml(CardData card, String html) {
    final regexp = RegExp(r'<img[^>]*src="([^"]+)"[^>]*>', caseSensitive: false, multiLine: true);

    final newHtml = html.replaceAllMapped(regexp, (match) {
      final matchStr = match[0]!;
      final fileName = match[1];
      if (fileName == null) return matchStr;

      final fileUrl = getFileUrl(card, fileName)??fileName;
      final str = matchStr.replaceFirst('src="$fileName', 'src="$fileUrl');
      return str;
    });

    return newHtml;
  }

  static Future<String?> prepareFieldContent(DbSource dbSource, int jsonFileID, String? source, Map<String, dynamic>? convertMap) async {
    if (source == null || source.isEmpty) return null;

    final fileExt     = FileExt.getFileExt(source);
    var   contentExt  = FileExt.getContentExt(source);
    final contentData = FileExt.getContentData(contentExt, source);

    if (( fileExt.isEmpty    || FileExt.txtExtList.contains(fileExt)  ) &&
        ( contentExt.isEmpty || contentTextFiles.contains(contentExt) ) &&
        ( fileExt.isNotEmpty || contentExt.isNotEmpty)
    ){

      String? fileContent;

      var fileUrl = dbSource.getFileUrl(jsonFileID, contentData);

      if (fileUrl != null) {
        fileContent = await getTextFromUrl(fileUrl);

        if (convertMap != null && fileContent != null) {
          convertMap.forEach((key, value) {
            fileContent =  fileContent!.replaceAll('${DjfTemplateSource.paramBegin}$key${DjfTemplateSource.paramEnd}', value);
          });
        }
      }

      fileContent ??= contentData;

      if (contentExt.isEmpty) {
        if (fileExt == contentTxt) {
          contentExt = contentText;
        } else {
          contentExt = fileExt;
        }
      }

      return '$contentExt:$fileContent';
    }

    if (contentExt.isNotEmpty) return source;

    String newContentExt = contentUnknown;

    if (fileExt.isNotEmpty) {
      if (imageExtList.contains(fileExt)) {
        newContentExt = contentImage;
      }
      if (audioExtList.contains(fileExt)) {
        newContentExt = contentAudio;
      }
      if (videoExtList.contains(fileExt)) {
        newContentExt = contentVideo;
      }

      if (txtExtList.contains(fileExt)) {
        newContentExt = fileExt;
      }
    }

    return '$newContentExt:$source';
  }

  static String? getFileUrl(CardData card, String fileName) {
    return card.dbSource.getFileUrl(card.pacInfo.jsonFileID, fileName);
  }
}

class CardData {
  final DbSource  dbSource;

  final PacInfo   pacInfo;
  final CardHead  head;
  final CardBody  body;
  final CardStyle style;
  final CardStat  stat;

  final RegDifficulty difficulty;

  final RegCardSet?  regSet;

  List<String>? _tagList;
  List<String> get tagList => _tagList??[];

  CardData({
    required this.dbSource,
    required this.head,
    required this.style,
    required this.body,
    required this.pacInfo,
    required this.stat,
    required this.difficulty,
    this.regSet,
  });

  static Future<CardData> create(
    DbSource dbSource,
    Regulator regulator,
    int jsonFileID,
    int cardID,
    {
      int? bodyNum,
      CardSetBody setBody = CardSetBody.random,
    }
  ) async {

    final card = await _CardGenerator.createCard(dbSource, regulator, jsonFileID, cardID, bodyNum: bodyNum, setBody: setBody);
    return card;
  }

  Future<void> fillTags() async {
    if (_tagList != null) return;

    _tagList = await dbSource.tabCardTag.getCardTags(jsonFileID: head.jsonFileID, cardID: head.cardID);
    _tagList!.add('${TagPrefix.cardKey}${head.cardKey}');
    if (head.group.isNotEmpty){
      _tagList!.add('${TagPrefix.group}${head.group}');
    }
    _tagList!.add('${TagPrefix.difficulty}${head.difficulty}');
  }
}

enum CardSetBody {
  none,
  first,
  last,
  random,
}

class _CardGenerator {
  static DbSource?     _dbSource;

  static PacInfo?   _pacInfo;
  static CardHead?  _cardHead;
  static CardBody?  _cardBody;
  static CardStyle? _cardStyle;

  static RegCardSet? _regSet;

  static Map<String, dynamic>? _convertMap;

  static final _random = Random();

  static Future<CardData> createCard(
      DbSource dbSource,
      Regulator regulator,
      int jsonFileID,
      int cardID,
      {
        int? bodyNum,
        CardSetBody setBody = CardSetBody.random,
      }) async {

    _dbSource   = dbSource;
    _pacInfo    = null;
    _cardHead   = null;
    _cardBody   = null;
    _cardStyle  = null;
    _regSet     = null;
    _convertMap = null;

    final pacData = await dbSource.tabJsonFile.getRow(jsonFileID: jsonFileID);
    _pacInfo = PacInfo.fromMap(pacData!);

    final headData = (await dbSource.tabCardHead.getRow(jsonFileID: jsonFileID, cardID: cardID))!;


    final templateSourceRowId = headData[TabCardHead.kSourceRowId];
    if (templateSourceRowId != null) {
      _convertMap = await dbSource.tabTemplateSource.getRow(jsonFileID: jsonFileID, sourceId: templateSourceRowId);
    }

    await CardHead.prepareMap(dbSource, _pacInfo!.jsonFileID, headData, _convertMap);
    _cardHead = CardHead.fromMap(headData);
    
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

    final statData = await dbSource.tabCardStat.getRow(jsonFileID: jsonFileID, cardID: cardID);
    final cardStat = CardStat.fromMap(statData!);

    if (_cardHead!.regulatorSetIndex != null) {
      _regSet = regulator.cardSetList[_cardHead!.regulatorSetIndex!];
    }
    RegDifficulty? difficulty;
    if (_regSet != null && _regSet!.difficultyLevel != null) {
      difficulty = regulator.getDifficulty(_regSet!.difficultyLevel!);
    } else {
      difficulty = regulator.getDifficulty(_cardHead!.difficulty);
    }
    
    final card = CardData(
        dbSource   : dbSource,
        head       : _cardHead!,
        body       : _cardBody!,
        style      : _cardStyle!,
        pacInfo    : _pacInfo!,
        stat       : cardStat,
        difficulty : difficulty,
        regSet     : _regSet,
    );

    return card;
  }

  static Future<void> _setBodyNum(int bodyNum) async {
    final bodyData = (await _dbSource!.tabCardBody.getRow(jsonFileID: _cardHead!.jsonFileID, cardID: _cardHead!.cardID, bodyNum: bodyNum))!;
    await CardBody.prepareMap(_dbSource!, _pacInfo!.jsonFileID, bodyData, _convertMap);
    _cardBody = CardBody.fromMap(bodyData);

    final Map<String, dynamic> styleMap = {};
    for (var styleKey in _cardBody!.styleKeyList) {
      final styleData = await _dbSource!.tabCardStyle.getRow(jsonFileID: _cardHead!.jsonFileID, cardStyleKey: styleKey );
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
  final bool dontShowAnswerOnDemo;       // boolean, default false, do NOT show in demo mode
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
    this.dontShowAnswerOnDemo = false,
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
      dontShowAnswerOnDemo       : json[DjfCardStyle.dontShowAnswerOnDemo]??false,
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
  final CardSource? help;
  final int    difficulty;
  final int    bodyCount;

  final int?    regulatorSetIndex;

  const CardHead({
    required this.cardID,
    required this.jsonFileID,
    required this.cardKey,
    required this.group,
    required this.title,
    required this.help,
    required this.difficulty,
    required this.bodyCount,
    required this.regulatorSetIndex
  });

  static Future<void> prepareMap(DbSource dbSource, int jsonFileID, Map<String, dynamic> map, Map<String, dynamic>? convertMap) async {
    map[DjfCard.help] = await FileExt.prepareFieldContent(dbSource, jsonFileID, map[DjfCard.help], convertMap);
  }

  factory CardHead.fromMap(Map<String, dynamic> json) {
    return CardHead(
      cardID     : json[TabCardHead.kCardID],
      jsonFileID : json[TabCardHead.kJsonFileID],
      cardKey    : json[TabCardHead.kCardKey],
      group      : json[TabCardHead.kGroup],
      title      : json[TabCardHead.kTitle],
      help       : json[TabCardHead.kHelp] != null? CardSource(json[TabCardHead.kHelp]!) : null,
      difficulty : json[TabCardHead.kDifficulty]??0,
      bodyCount  : json[TabCardHead.kBodyCount],
      regulatorSetIndex : json[TabCardHead.kRegulatorSetIndex],
    );
  }
}

class CardBody {
  final int    id;                // integer, body identifier in the database
  final int    jsonFileID;        // integer, file identifier in the database
  final int    cardID;            // integer, card identifier in the database
  final int    bodyNum;           // integer, body number
  final List<CardSource> questionData;
  final List<String> styleKeyList; // List of global styles
  final Map<String, dynamic> styleMap; // Own body style
  final List<String> answerList;
  final CardSource? clue;

  const CardBody({
    required this.id,
    required this.jsonFileID,
    required this.cardID,
    required this.bodyNum,
    required this.questionData,
    required this.styleKeyList,
    required this.styleMap,
    required this.answerList,
    required this.clue
  });

  static Future<void> prepareMap(DbSource dbSource, int jsonFileID, Map<String, dynamic> map, Map<String, dynamic>? convertMap) async {
    map[DjfCardBody.clue] = await FileExt.prepareFieldContent(dbSource, jsonFileID, map[DjfCardBody.clue], convertMap);

    final questionDataList = map[ DjfCardBody.questionData] as List<dynamic>;

    for (var i = 0; i < questionDataList.length; i ++) {
      questionDataList[i] = await FileExt.prepareFieldContent(dbSource, jsonFileID, questionDataList[i], convertMap);
    }
  }

  factory CardBody.fromMap(Map<String, dynamic> json) {
    return CardBody(
      id                : json[TabCardBody.kID],
      jsonFileID        : json[TabCardBody.kJsonFileID],
      cardID            : json[TabCardBody.kCardID],
      bodyNum           : json[TabCardBody.kBodyNum],
      questionData      : json[DjfCardBody.questionData] != null ? List<CardSource>.from(json[ DjfCardBody.questionData].map((x) => CardSource(x))) : [],
      styleKeyList      : json[DjfCardBody.styleIdList] != null ? List<String>.from(json[ DjfCardBody.styleIdList].map((x) => x)) : [],
      styleMap          : json[DjfCardBody.style]??{},
      answerList        : json[DjfCardBody.answerList] != null ? List<String>.from(json[ DjfCardBody.answerList].map((x) => x)) : [],
      clue              : json[DjfCardBody.clue] != null ? CardSource(json[DjfCardBody.clue]!) : null,
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
  final String sourceFileID;
  final String title;
  final String guid;
  final int    version;
  final String author;
  final String site;
  final String email;
  final String license;
  final String? sourceDir;

  PacInfo({
    required this.jsonFileID,
    required this.sourceFileID,
    required this.title,
    required this.guid,
    required this.version,
    required this.author,
    required this.site,
    required this.email,
    required this.license,
    this.sourceDir,
  });

  factory PacInfo.fromMap(Map<String, dynamic> json){
    return PacInfo(
      jsonFileID   : json[TabJsonFile.kJsonFileID],
      sourceFileID : json[TabJsonFile.kSourceFileID],
      title        : json[TabJsonFile.kTitle],
      guid         : json[TabJsonFile.kGuid],
      version      : json[TabJsonFile.kVersion],
      author       : json[TabJsonFile.kAuthor],
      site         : json[TabJsonFile.kSite],
      email        : json[TabJsonFile.kEmail],
      license      : json[TabJsonFile.kLicense],
      sourceDir    : json[TabJsonFile.kRootPath],
    );
  }
}