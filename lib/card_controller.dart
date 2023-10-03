import 'dart:math';
import 'package:collection/collection.dart';
import 'package:decard/app_state.dart';
import 'package:decard/regulator.dart';

import 'package:sqflite/sqflite.dart';

import 'package:simple_events/simple_events.dart';
import 'child.dart';
import 'common.dart';
import 'db.dart';
import 'card_model.dart';


final _random = Random();

class CardController {
  final Child child;
  final ProcessCardController processCardController;

  CardController({
    required this.child,
    required this.processCardController,
  });

  CardData? _card;
  CardData? get card => _card;

  final onChange = SimpleEvent();
  final onAddEarn = SimpleEvent<double>();

  final cardResultList = <TestResult>[];

  Listener<CardData>? _cardListener;

  /// Sets the current card data
  Future<void> setCard(int jsonFileID, int cardID, {int? bodyNum, CardSetBody setBody = CardSetBody.random, int startTime = 0}) async {
    if (_cardListener != null) {
      _cardListener!.dispose();
      _cardListener = null;
    }

    _card = await CardData.create(child, jsonFileID, cardID, bodyNum: bodyNum, setBody: setBody);
    _cardListener = _card!.onResult.subscribe((listener, card) {
      _onCardResult(card!);
    });

    _card!.startTime = startTime;

    await processCardController.setCard(cardID);
    onChange.send();
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

  Future<void> _onCardResult(CardData card) async {
    if (appState.appMode == AppMode.demo) return;

    final newStat = await processCardController.registerResult(card.head.jsonFileID, card.head.cardID, card.result!);

    final testResult = TestResult(
        fileGuid      : card.pacInfo.guid,
        fileVersion   : card.pacInfo.version,
        cardID        : card.head.cardKey,
        bodyNum       : card.body.bodyNum,
        result        : card.result!,
        earned        : card.earned,
        tryCount      : card.resultTryCount,
        solveTime     : card.solveTime,
        dateTime      : dateTimeToInt(DateTime.now()),
        qualityBefore : card.stat.quality,
        qualityAfter  : newStat.quality,
        difficulty    : card.head.difficulty
    );

    cardResultList.add(testResult);

    onAddEarn.send(card.earned);

    child.dbSource.tabTestResult.insertRow(testResult);
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
    const String sql = '''
      SELECT
        ${TabCardStat.tabName}.${TabCardStat.kID}, 
        ${TabCardStat.tabName}.${TabCardStat.kJsonFileID}, 
        ${TabCardStat.tabName}.${TabCardStat.kCardID}, 
        ${TabCardStat.tabName}.${TabCardStat.kCardGroupKey}, 
        ${TabCardStat.tabName}.${TabCardStat.kQuality}, 
        ${TabCardStat.tabName}.${TabCardStat.kLastResult}
        FROM ${TabCardStat.tabName}
        JOIN ${TabCardHead.tabName}
          ON ${TabCardHead.tabName}.${TabCardHead.kCardID} = ${TabCardStat.tabName}.${TabCardStat.kCardID}
       WHERE ${TabCardStat.tabName}.${TabCardStat.kTestsCount} > 0 
         AND ${TabCardStat.tabName}.${TabCardStat.kQuality} < ${Regulator.maxQuality}
         AND ${TabCardHead.tabName}.${TabCardHead.kExclude} = 0
       ORDER BY ${TabCardStat.tabName}.${TabCardStat.kID}  
    ''';

    final rows = await db.rawQuery(sql);

    cardStatList.clear();
    cardStatList.addAll(rows.map((row) => ProcessCardStat.fromMap(row)));

    // Initialize the list of groups
    for (var stat in cardStatList) {
      await _prepareGroup(stat);
    }
  }

  Future<void> setCard(int cardID) async {
    if (cardStatList.any((stat) => stat.cardID == cardID)) return;

    final statData = await tabCardStat.getRow(cardID);
    final cardStat = ProcessCardStat.fromMap(statData!);
    cardStatList.add(cardStat);
    await _prepareGroup(cardStat);
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

    if (testsCount == 0) {
      row[TabCardStat.kStartDate] = _curDay;
    }

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
      f += ( Regulator.maxQuality * dayResult.countOk ) / dayResult.countTotal;
    }

   var quality = f ~/ dayResultList.length;

   if (dayResult.countTotal <= _options.lowTryCount || dayResultList.length <= _options.lowDayCount) {
     final xQuality = (Regulator.maxQuality * dayResult.countTotal * dayResultList.length) ~/ (_options.lowTryCount * _options.lowDayCount);
     if (quality > xQuality) quality = xQuality;
   }

   if (quality >= Regulator.maxQuality) quality = Regulator.completelyStudiedQuality;

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
    
    WHERE mainCard.${TabCardHead.kExclude} = 0 
     
    AND NOT EXISTS ( --selecting cards that have not yet been studied
        SELECT 1
          FROM ${TabCardStat.tabName} as sub1
         WHERE sub1.${TabCardStat.kJsonFileID} = mainCard.${TabCardHead.kJsonFileID}
           AND sub1.${TabCardStat.kCardID}     = mainCard.${TabCardHead.kCardID}
           AND sub1.${TabCardStat.kTestsCount} > 0
    )
    
    AND $isStudied EXISTS ( --select groups that have not yet been studied/studied
        SELECT 1
          FROM ${TabCardStat.tabName} as sub2
         WHERE sub2.${TabCardStat.kJsonFileID}   = mainCard.${TabCardHead.kJsonFileID}
           AND sub2.${TabCardStat.kCardGroupKey} = mainCard.${TabCardHead.kGroup}
           AND sub2.${TabCardStat.kTestsCount}   > 0
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
                     min( ifNull( stat.${TabCardStat.kQuality}, 0) ) as min,
                     avg( ifNull( stat.${TabCardStat.kQuality}, 0) ) as avg
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
      totalNQuality += (Regulator.maxQuality - _actQuality(stat));
    }

    final selNQuality = _random.nextInt(totalNQuality + 1);

    int curNQuality = 0;
    int selIndex = 0;
    for (int i = 0; i < cardStatList.length; i++){
      final stat = cardStatList[i];

      if (_actQuality(stat) < Regulator.maxQuality) {
        curNQuality += (Regulator.maxQuality - _actQuality(stat));
        if (curNQuality > selNQuality) {
          selIndex = i;
          break;
        }
      }
    }

    final stat = cardStatList[selIndex];
    return CardPointer(stat.jsonFileID, stat.cardID);
  }
}
