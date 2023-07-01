import 'dart:math';
import 'package:collection/collection.dart';
import 'package:decard/app_state.dart';
import 'package:decard/regulator.dart';

import 'package:sqflite/sqflite.dart';

import 'package:simple_events/simple_events.dart';
import 'common.dart';
import 'db.dart';
import 'card_model.dart';


final _random = Random();

enum CardSetBody {
  none,
  first,
  last,
  random,
}

class CardController {
  final DbSource dbSource;
  final ProcessCardController processCardController;
  final Regulator regulator;

  CardController({
    required this.dbSource,
    required this.processCardController,
    required this.regulator,
  });

  PacInfo?   _pacInfo;
  CardHead?  _cardHead;
  CardBody?  _cardBody;
  CardStyle? _cardStyle;
  CardStat?  _cardStat;

  RegCardSet?    _regSet;

  RegDifficulty? _difficulty;
  int _bodyNum = 0;

  CardData? _card;
  CardData? get card => _card;

  final onChange = SimpleEvent();
  final onAddEarn = SimpleEvent<double>();

  final cardResultList = <TestResult>[];

  /// Sets the current card data
  Future<void> setCard(int jsonFileID, int cardID, {int? bodyNum, CardSetBody setBody = CardSetBody.random}) async {
    _pacInfo   = null;
    _cardHead  = null;
    _cardBody  = null;
    _cardStyle = null;
    _cardStat  = null;
    _regSet    = null;

    final headData = await dbSource.tabCardHead.getRow(cardID);
    _cardHead = CardHead.fromMap(headData!);

    if (_cardHead!.regulatorSetIndex != null) {
      _regSet = regulator.cardSetList[_cardHead!.regulatorSetIndex!];
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

    final statData = await processCardController.getStatData(cardID);
    _cardStat = CardStat.fromMap(statData!);

    final pacData = await dbSource.tabJsonFile.getRow(jsonFileID: jsonFileID);
    _pacInfo = PacInfo.fromMap(pacData!);

    if (_regSet != null && _regSet!.difficultyLevel != null) {
      _difficulty = regulator.getDifficulty(_regSet!.difficultyLevel!);
    } else {
      _difficulty = regulator.getDifficulty(_cardHead!.difficulty);
    }

    _card = CardData(
        head       : _cardHead!,
        body       : _cardBody!,
        style      : _cardStyle!,
        stat       : _cardStat!,
        pacInfo    : _pacInfo!,
        difficulty : _difficulty!,
        regSet     : _regSet,
        onResult   : _onCardResult
    );

    onChange.send();
  }

  /// Sets the specified body in the current card
  Future<void> setBodyNum(int bodyNum) async {
    await _setBodyNum(bodyNum);
    _card!.body  = _cardBody!;
    _card!.style = _cardStyle!;
    onChange.send();
  }

  Future<void> _setBodyNum(int bodyNum) async {
    _bodyNum = bodyNum;

    final bodyData = await dbSource.tabCardBody.getRow(jsonFileID: _cardHead!.jsonFileID, cardID: _cardHead!.cardID, bodyNum: bodyNum );
    _cardBody = CardBody.fromMap(bodyData!);

    final Map<String, dynamic> styleMap = {};
    for (var styleKey in _cardBody!.styleKeyList) {
      final styleData = await dbSource.tabCardStyle.getRow(jsonFileID: _cardHead!.jsonFileID, cardStyleKey: styleKey );
      styleMap.addEntries(styleData!.entries.where((element) => element.value != null));
    }

    styleMap.addEntries(_cardBody!.styleMap.entries.where((element) => element.value != null));

    if (_regSet != null && _regSet!.style != null) {
      styleMap.addEntries(_regSet!.style!.entries.where((element) => element.value != null));
    }

    _cardStyle = CardStyle.fromMap(styleMap);
  }

  Future<void> _setRandomBodyNum() async {
    int bodyNum = 0;
    if (_cardHead!.bodyCount > 1) bodyNum = _random.nextInt(_cardHead!.bodyCount);

    await _setBodyNum(bodyNum);
  }

  Future<bool> selectNextCard() async {
    CardPointer? newCard;

    for (int i = 0; i < 10; i++) { // so that the last issued card is not reissued
      newCard = await processCardController.getCardForTest();
      if (newCard == null) return false;

      if (card?.head.cardID != newCard.cardID || card?.head.jsonFileID != newCard.jsonFileID){
        break;
      }
    }

    if (newCard == null) return false;
    await setCard( newCard.jsonFileID, newCard.cardID );

    return true;
  }

  Future<void> _onCardResult(bool result, double earn) async {
    if (appState.appMode == AppMode.demo) return;

    final newStat = await processCardController.registerResult(_cardHead!.jsonFileID, _cardHead!.cardID, result);

    final testResult = TestResult(
        fileGuid      : _pacInfo!.guid,
        fileVersion   : _pacInfo!.version,
        cardID        : _cardHead!.cardKey,
        bodyNum       : _bodyNum,
        result        : result,
        earned        : earn,
        dateTime      : dateTimeToInt(DateTime.now()),
        qualityBefore : _cardStat!.quality,
        qualityAfter  : newStat.quality,
        difficulty    : _cardHead!.difficulty
    );

    cardResultList.add(testResult);

    onAddEarn.send(earn);

    dbSource.tabTestResult.insertRow(testResult);
  }
}

class ProcessCardStat {
  final int    statID;
  final int    jsonFileID;
  final int    cardID;
  final String cardGroupKey;

  bool lastResult;
  int  quality;

  late String groupKey;

  ProcessCardStat({ required this.statID, required this.jsonFileID, required this.cardID, required this.cardGroupKey, required this.quality, required this.lastResult }){
    if (cardGroupKey.isEmpty) {
      groupKey = '@$cardID';
    } else {
      groupKey = '#$jsonFileID/$cardGroupKey';
    }
  }

  factory ProcessCardStat.fromMap(Map<String, dynamic> json) {
    return ProcessCardStat(
      statID       : json[TabCardStat.kID],
      jsonFileID   : json[TabCardStat.kJsonFileID],
      cardID       : json[TabCardStat.kCardID],
      cardGroupKey : json[TabCardStat.kCardGroupKey],
      quality      : json[TabCardStat.kQuality],
      lastResult   : (json[TabCardStat.kLastResult]??0)==1,
    );
  }
}

class _CardGroup {
  final String groupKey;
  final int cardCount; // number of cards in the group per file

  int lowQuality   = 0;
  int totalQuality = 0;
  int statCount    = 0;

  _CardGroup(this.groupKey, this.cardCount);

  addQuality(int quality){
    if (lowQuality < quality) lowQuality = quality;
    totalQuality += quality;
    statCount ++;
  }

  clear(){
    lowQuality   = 0;
    totalQuality = 0;
    statCount    = 0;
  }
}

/// Provides analysis of statistics for card selection
class ProcessCardController {
  /// quality >= 99 - the card is completely studied;
  /// quality >= 0 - study started
  /// quality = -1 - study not started

  static const int maxQuality         = 100; // Maximum learning quality

  final Database db;

  final Regulator regulator;
  late RegOptions _options;

  final cardStatList = <ProcessCardStat>[];
  final groupList    = <_CardGroup>[];

  final TabCardStat tabCardStat;
  final TabCardHead tabCardHead;

  ProcessCardController(this.db, this.regulator, this.tabCardStat, this.tabCardHead);

  /// for testing and debugging
  int _testDate = 0;
  void setTestDate(DateTime date){
    _testDate = dateToInt(date);
  }

  int get _curDay {
    if (_testDate != 0) return _testDate;
    return dateToInt(DateTime.now());
  }

  /// initialization/preparation
  Future<void> init() async {
    _options = regulator.options;
    await _loadCardStat();
  }

  /// Loading statistics from the database
  Future<void> _loadCardStat() async {
    final rows = await db.query(TabCardStat.tabName,
      columns   : [TabCardStat.kID, TabCardStat.kJsonFileID, TabCardStat.kCardID, TabCardStat.kCardGroupKey, TabCardStat.kQuality, TabCardStat.kLastResult],
      orderBy   : TabCardStat.kID,
    );

    cardStatList.clear();
    cardStatList.addAll(rows.map((row) => ProcessCardStat.fromMap(row)));

    // Initialize the list of groups
    for (var stat in cardStatList) {
      await _prepareGroup(stat);
    }
  }

  Future<_CardGroup> _prepareGroup(ProcessCardStat stat) async {
    final group = groupList.firstWhereOrNull((group) => group.groupKey == stat.groupKey);
    if (group != null) return group;

    int cardCount = 1;
    if (stat.cardGroupKey.isNotEmpty) {
      cardCount = await tabCardHead.getGroupCardCount(jsonFileID: stat.jsonFileID, cardGroupKey: stat.cardGroupKey);
    }

    final newGroup = _CardGroup(stat.groupKey, cardCount);
    newGroup.addQuality(stat.quality);
    groupList.add(newGroup);

    return newGroup;
  }

  /// Registration of the test result on the card
  Future<ProcessCardStat> registerResult(int jsonFileID, int cardID, bool resultOk) async {
    final rows = await db.query(TabCardStat.tabName,
      where     : '${TabCardStat.kJsonFileID} = ? and ${TabCardStat.kCardID} = ?',
      whereArgs : [jsonFileID, cardID],
    );

    final row = Map<String, Object?>.from(rows[0]) ;

    row[TabCardStat.kLastTestDate] = _curDay;

    final testsCount = row[TabCardStat.kTestsCount] as int;
    row[TabCardStat.kTestsCount] = testsCount + 1;

    final jsonStr = row[TabCardStat.kJson] as String?;
    final dayResultList = tabCardStat.dayResultsFromJson(jsonStr??'');

    DayResult? dayResult;
    dayResult = dayResultList.firstWhereOrNull((dayResult) => dayResult.day == _curDay);
    if (dayResult == null) {
      dayResult = DayResult(day: _curDay);
      dayResultList.add(dayResult);
    }

    dayResult.addResult(resultOk);

    while (dayResultList.length > _options.hotDayCount) {
      dayResultList.removeAt(0);
    }

    double f = 0;
    for (var dayResult in dayResultList) {
      f += ( maxQuality * dayResult.countOk ) / dayResult.countTotal;
    }

   var quality = f ~/ dayResultList.length;

   if (dayResult.countTotal <= _options.lowTryCount || dayResultList.length <= _options.lowDayCount) {
     final xQuality = (maxQuality * dayResult.countTotal * dayResultList.length) ~/ (_options.lowTryCount * _options.lowDayCount);
     if (quality > xQuality) quality = xQuality;
   }

   if (quality >= maxQuality) quality = maxQuality - 1;

    row[TabCardStat.kQuality] = quality;

    row[TabCardStat.kJson] = TabCardStat.dayResultsToJson(dayResultList);

    row[TabCardStat.kQualityFromDate] = dayResultList[0].day;

    row[TabCardStat.kLastResult] = resultOk;

    final rowID = row[TabCardStat.kID] as int;
    row.remove(TabCardStat.kID);

    await db.update(TabCardStat.tabName, row,
      where: '${TabCardStat.kID} = ?',
      whereArgs: [rowID]
    );

    final cardStat = cardStatList.firstWhere((cardStat) => cardStat.statID == rowID);
    cardStat.quality    = quality;
    cardStat.lastResult = resultOk;

    return cardStat;
  }

  Future<void> _refreshGroupInfo() async {
    for (var group in groupList) {
      group.clear();
    }

    for (var stat in cardStatList) {
      final group = await _prepareGroup(stat);

      group.addQuality(stat.quality);
    }
  }

  /// Selects a card to test
  Future<CardPointer?> getCardForTest() async {

    int countHotCard = 0;
    for (var stat in cardStatList) {
      if (stat.quality <= _options.hotCardQualityTopLimit) {
        countHotCard ++;
      }
    }

    if (countHotCard >= _options.maxCountHotCard) {
      // Choose a card among those already studied
      final cardPointer = _selectStudiedCard();
      return cardPointer;
    }

    await _refreshGroupInfo();

    int countHotGroup = 0;
    int countLowGroup = 0;
    for (var group in groupList) {
      if ( group.statCount < group.cardCount
      ||   group.lowQuality <= _options.hotGroupMinQualityTopLimit
      ||   ((group.totalQuality / group.statCount) <= _options.hotGroupAvgQualityTopLimit )
      ){
        countHotGroup ++;
      }

      if ((group.totalQuality / group.statCount) <= _options.lowGroupAvgQualityTopLimit) {
        countLowGroup ++;
      }
    }

    if (countHotGroup < _options.minCountHotQualityGroup && countLowGroup < _options.maxCountLowQualityGroup ) {
      // Select a new group, and select the first card in the group
      final cardPointer = await _selectNewCard( false );
      if (cardPointer != null) return cardPointer;
    }

    {
      // Trying to select a new card from among the groups already being studied
      final cardPointer = await _selectNewCard( true );
      if (cardPointer != null) return cardPointer;
    }

    {
      // Choose a card from among those already being studied
      final cardPointer = _selectStudiedCard();
      return cardPointer;
    }

  }

  Future<CardPointer?> _selectNewCard(bool groupIsStudied) async {
    final String isStudied = groupIsStudied? "" : "NOT";

    final String sql = '''SELECT
      mainCard.${TabCardHead.kJsonFileID},
      min( mainCard.${TabCardHead.kCardID} ) AS ${TabCardHead.kCardID}
    FROM ${TabCardHead.tabName} as mainCard
    
    WHERE ${TabCardHead.kExclude} = 0 
     
    AND NOT EXISTS ( --selecting cards that have not yet been studied
        SELECT 1
          FROM ${TabCardStat.tabName} as sub1
         WHERE sub1.${TabCardStat.kJsonFileID} = mainCard.${TabCardHead.kJsonFileID}
           AND sub1.${TabCardStat.kCardID}     = mainCard.${TabCardHead.kCardID}
    )
    
    AND $isStudied EXISTS ( --select groups that have not yet been studied/studied
        SELECT 1
          FROM ${TabCardStat.tabName} as sub2
         WHERE sub2.${TabCardStat.kJsonFileID}   = mainCard.${TabCardHead.kJsonFileID}
           AND sub2.${TabCardStat.kCardGroupKey} = mainCard.${TabCardHead.kGroup}
    )
    
    AND NOT EXISTS ( --the card has no links with an unfulfilled condition
        SELECT 1
          FROM ${TabCardLink.tabName}     as link
          JOIN ${TabQualityLevel.tabName} as qLevel
            ON qLevel.${TabQualityLevel.kJsonFileID}  = link.${TabCardHead.kJsonFileID}
           AND qLevel.${TabQualityLevel.kQualityName} = link.${TabCardLink.kQualityName}
         WHERE link.${TabCardLink.kCardID} = mainCard.${TabCardHead.kCardID}
           AND EXISTS (
               SELECT 1
                 FROM (
    
                 SELECT
                     min( ifNull( stat.${TabCardStat.kQuality}, -1) ) as min,
                     avg( ifNull( stat.${TabCardStat.kQuality}, -1) ) as avg
                   FROM ${TabCardHead.tabName}            as testCard
              LEFT JOIN ${TabCardStat.tabName}            as stat
                     ON stat.${TabCardStat.kJsonFileID}   = testCard.${TabCardHead.kJsonFileID}
                    AND stat.${TabCardStat.kCardID}       = testCard.${TabCardHead.kCardID}
                  WHERE testCard.${TabCardHead.kJsonFileID} = link.${TabCardHead.kJsonFileID}
                    AND testCard.${TabCardHead.kCardID} IN (
    
                        SELECT DISTINCT tag.${TabCardTag.kCardID}
                          FROM ${TabCardLinkTag.tabName}     as linkTag
                          JOIN ${TabCardTag.tabName}         as tag
                            ON tag.${TabCardTag.kTag}                = linkTag.${TabCardLinkTag.kTag}
                           AND tag.${TabCardTag.kJsonFileID}         = link.${TabCardHead.kJsonFileID}
                         WHERE linkTag.${TabCardLinkTag.kJsonFileID} = link.${TabCardHead.kJsonFileID}
                           AND linkTag.${TabCardLinkTag.kLinkID}     = link.${TabCardLink.kLinkID}
                           AND tag.${TabCardTag.kCardID}             < mainCard.${TabCardHead.kCardID} --The cards that are higher in the file are selected
    
                    )
    
                 ) as sub3
                 WHERE ( sub3.min < qLevel.${TabQualityLevel.kMinQuality} OR sub3.avg < qLevel.${TabQualityLevel.kAvgQuality} )
           )
    
    )
    GROUP BY mainCard.${TabCardHead.kJsonFileID}''';

    final rows = await db.rawQuery(sql);
    if (rows.isEmpty) return null;

    int rndIndex = 0;
    if (rows.length > 1) rndIndex = _random.nextInt(rows.length);

    final row = rows[rndIndex];

    final jsonFileID = row[TabCardLink.kJsonFileID] as int;
    final cardID     = row[TabCardLink.kCardID]     as int;

    return CardPointer(jsonFileID, cardID);
  }

  int _actQuality(ProcessCardStat stat) {
    if (stat.lastResult) return stat.quality;
    if (stat.quality < _options.negativeLastResultMaxQualityLimit) return stat.quality;
    return _options.negativeLastResultMaxQualityLimit;
  }

  /// Selects a card for testing
  CardPointer? _selectStudiedCard() {
    if (cardStatList.isEmpty) return null;

    int totalNQuality = 0;

    for (var stat in cardStatList) {
      totalNQuality += (maxQuality - _actQuality(stat));
    }

    final selNQuality = _random.nextInt(totalNQuality + 1);

    int curNQuality = 0;
    int selIndex = 0;
    for (int i = 0; i < cardStatList.length; i++){
      final stat = cardStatList[i];

      if (_actQuality(stat) < maxQuality) {
        curNQuality += (maxQuality - _actQuality(stat));
        if (curNQuality > selNQuality) {
          selIndex = i;
          break;
        }
      }
    }

    final stat = cardStatList[selIndex];
    return CardPointer(stat.jsonFileID, stat.cardID);
  }

  Future<ProcessCardStat> _initStatData(int cardID) async {
    final cardHead = await tabCardHead.getRow(cardID);

    final jsonFileID    = cardHead![TabCardHead.kJsonFileID] as int;
    final cardKey       = cardHead[TabCardHead.kCardKey]     as String;
    final cardGroupKey  = cardHead[TabCardHead.kGroup]       as String;

    final id = await tabCardStat.insertRow(jsonFileID: jsonFileID, cardID: cardID, cardKey: cardKey, cardGroupKey: cardGroupKey, quality: 0, lastResult: false, date: _curDay);

    final cardStat = ProcessCardStat(statID: id, jsonFileID: jsonFileID, cardID: cardID, cardGroupKey: cardGroupKey, quality: 0, lastResult: false);

    cardStatList.add(cardStat);

    await _prepareGroup(cardStat);

    return cardStat;
  }

  Future<Map<String, dynamic>?> getStatData(int cardID) async {
    final statData = await tabCardStat.getRow(cardID);
    if (statData != null) return statData;

    await _initStatData(cardID);

    final newStatData = await tabCardStat.getRow(cardID);
    return newStatData;
  }
}
