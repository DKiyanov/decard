import 'dart:math';
import 'package:collection/collection.dart';

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

  CardController({
    required this.dbSource,
    required this.processCardController,
  });

  PacInfo?   _pacInfo;
  CardHead?  _cardHead;
  CardBody?  _cardBody;
  CardStyle? _cardStyle;
  CardStat?  _cardStat;

  CardData? _card;
  CardData? get card => _card;

  final onChange = SimpleEvent();
  final onAddEarn = SimpleEvent<double>();

  /// Устанавливает данные текущей карточки
  Future<void> setCard(int jsonFileID, int cardID, {int? bodyNum, CardSetBody setBody = CardSetBody.random}) async {
    _pacInfo   = null;
    _cardHead  = null;
    _cardBody  = null;
    _cardStyle = null;
    _cardStat  = null;

    final headData = await dbSource.tabCardHead.getRow(cardID);
    _cardHead = CardHead.fromMap(headData!);

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

    _card = CardData(head : _cardHead!, body: _cardBody!, style: _cardStyle!, stat: _cardStat!, pacInfo : _pacInfo!, onResult: _onCardResult );

    onChange.send();
  }

  /// Устанавливает заданное тело в текущей карточке
  Future<void> setBodyNum(int bodyNum) async {
    await _setBodyNum(bodyNum);
    _card!.body  = _cardBody!;
    _card!.style = _cardStyle!;
    onChange.send();
  }

  Future<void> _setBodyNum(int bodyNum) async {
    final bodyData = await dbSource.tabCardBody.getRow(jsonFileID: _cardHead!.jsonFileID, cardID: _cardHead!.cardID, bodyNum: bodyNum );
    _cardBody = CardBody.fromMap(bodyData!);

    final Map<String, dynamic> styleMap = {};
    for (var styleKey in _cardBody!.styleKeyList) {
      final styleData = await dbSource.tabCardStyle.getRow(jsonFileID: _cardHead!.jsonFileID, cardStyleKey: styleKey );
      styleMap.addEntries(styleData!.entries.where((element) => element.value != null));
    }

    styleMap.addEntries(_cardBody!.styleMap.entries.where((element) => element.value != null));

    _cardStyle = CardStyle.fromMap(styleMap);
  }

  Future<void> _setRandomBodyNum() async {
    int bodyNum = 0;
    if (_cardHead!.bodyCount > 1) bodyNum = _random.nextInt(_cardHead!.bodyCount);

    await _setBodyNum(bodyNum);
  }

  Future<bool> selectNextCard() async {
    CardPointer? newCard;

    for (int i = 0; i < 10; i++) { // чтоб повторно не выдавалась последняя выданная карточка
      newCard = await processCardController.getCardForTest();
      if (newCard == null) return false;

      if (card?.head.cardID != newCard.id || card?.head.jsonFileID != newCard.jsonFileID){
        break;
      }
    }

    if (newCard == null) return false;
    await setCard( newCard.jsonFileID, newCard.id );

    return true;
  }

  void _onCardResult(bool result, double earn){
    processCardController.registerResult(_cardHead!.jsonFileID, _cardHead!.cardID, result);
    onAddEarn.send(earn);
  }
}

class ProcessCardStat {
  final int    statID;
  final int    jsonFileID;
  final int    cardID;
  final String cardGroupKey;

  int quality;
  late String groupKey;

  ProcessCardStat({ required this.statID, required this.jsonFileID, required this.cardID, required this.cardGroupKey, required this.quality }){
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
    );
  }
}

class _CardGroup {
  final String groupKey;
  final int cardCount; // количесво карточек в групе в файле

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

/// Обеспечивает анализ статистики для выбора карточки
class ProcessCardController {
  /// quality = 99 - картичка полностью изучена;
  /// quality >= 0 - изучение начато
  /// quality = -1 - изучение не начато

  static const int maxQuality         = 100; // Максимальное качество изучения
  static const int hotDayCount        = 7;   // Количество дней для которых расчитывается стстистика

  static const int hotCardQualityTopLimit = 70; // карточки с меньшим качеством считаются активно изучаемыми
  static const int maxCountHotCard = 20;           // Максимальное кол-во карточек в активном изучении

  ///лимиты для определения активности группы
  static const int hotGroupMinQualityTopLimit = 60; // Минимальное качество по карточам входящим в группу
  static const int hotGroupAvgQualityTopLimit = 70; // Среднее качество по карточкам входящим в группу

  /// минимальое кол-во активно изучаемых групп,
  /// если кол-во меньше лимита - система пытается выбрать карточку из новой группы
  static const int minCountHotGroup = 15;

  /// понижение качества при малом объёме статистики
  ///   если по новой карточке с самого начала будут очень хорошие результаты
  ///   эти переметры не дадут рости качеству слшком быстро
  static const int lowTryCount = 7; // минимальное кол-во тестов
  static const int lowDayCount = 3; // минимальное кол-во дней

  final Database db;

  final cardStatList = <ProcessCardStat>[];
  final groupList    = <_CardGroup>[];

  final TabCardStat tabCardStat;
  final TabCardHead tabCardHead;

  ProcessCardController(this.db, this.tabCardStat, this.tabCardHead);

  /// для тестирования и отладки
  int _testDate = 0;
  void setTestDate(DateTime date){
    _testDate = dateToInt(date);
  }

  int get _curDay {
    if (_testDate != 0) return _testDate;
    return dateToInt(DateTime.now());
  }

  /// инциализация/подготовка
  Future<void> init() async {
    await _loadCardStat();
  }

  /// Загрузка статистики из БД
  Future<void> _loadCardStat() async {
    final rows = await db.query(TabCardStat.tabName,
      columns   : [TabCardStat.kID, TabCardStat.kJsonFileID, TabCardStat.kCardID, TabCardStat.kCardGroupKey, TabCardStat.kQuality],
      orderBy   : TabCardStat.kID,
    );

    cardStatList.clear();
    cardStatList.addAll(rows.map((row) => ProcessCardStat.fromMap(row)));

    // Инициализируем список групп
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

  /// Регистрация результата тестирования по карточке
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

    while (dayResultList.length > hotDayCount) {
      dayResultList.removeAt(0);
    }

    double f = 0;
    for (var dayResult in dayResultList) {
      f += ( maxQuality * dayResult.countOk ) / dayResult.countTotal;
    }

   var quality = f ~/ dayResultList.length;

   if (dayResult.countTotal <= lowTryCount || dayResultList.length <= lowDayCount) {
     final xQuality = (maxQuality * dayResult.countTotal * dayResultList.length) ~/ (lowTryCount * lowDayCount);
     if (quality > xQuality) quality = xQuality;
   }

   if (quality == maxQuality) quality = maxQuality - 1;

    row[TabCardStat.kQuality] = quality;

    row[TabCardStat.kJson] = TabCardStat.dayResultsToJson(dayResultList);

    row[TabCardStat.kQualityFromDate] = dayResultList[0].day;

    final rowID = row[TabCardStat.kID] as int;
    row.remove(TabCardStat.kID);

    await db.update(TabCardStat.tabName, row,
      where: '${TabCardStat.kID} = ?',
      whereArgs: [rowID]
    );

    final cardStat = cardStatList.firstWhere((cardStat) => cardStat.statID == rowID);
    cardStat.quality = quality;

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

  /// Выбирает карточку для тестирования
  Future<CardPointer?> getCardForTest() async {

    int countHotCard = 0;
    for (var stat in cardStatList) {
      if (stat.quality <= hotCardQualityTopLimit) {
        countHotCard ++;
      }
    }

    if (countHotCard >= maxCountHotCard) {
      // Выбираем карточку стерди уже изучаемых
      final cardPointer = _selectStudiedCard();
      return cardPointer;
    }

    await _refreshGroupInfo();

    int countHotGroup = 0;
    for (var group in groupList) {
      if ( group.statCount < group.cardCount
      ||   group.lowQuality <= hotGroupMinQualityTopLimit
      ||   ((group.totalQuality / group.statCount) <= hotGroupAvgQualityTopLimit )
      ){
        countHotGroup ++;
      }
    }

    if (countHotGroup < minCountHotGroup) {
      // Выбираем новую группу, а в группе выбираем первую карточку
      final cardPointer = await _selectNewCard( false );
      if (cardPointer != null) return cardPointer;
    }

    {
      // Пытаемся выбрать новую картоку среди уже изучаемых групп
      final cardPointer = await _selectNewCard( true );
      if (cardPointer != null) return cardPointer;
    }

    {
      // Выбираем карточку стерди уже изучаемых
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
    
    WHERE NOT EXISTS ( --отбираем карточки которые ещё не изучались
        SELECT 1
          FROM ${TabCardStat.tabName} as sub1
         WHERE sub1.${TabCardStat.kJsonFileID} = mainCard.${TabCardHead.kJsonFileID}
           AND sub1.${TabCardStat.kCardID}     = mainCard.${TabCardHead.kCardID}
    )
    
    AND $isStudied EXISTS ( --отбираем группы которые ещё не изучались/изучались
        SELECT 1
          FROM ${TabCardStat.tabName} as sub2
         WHERE sub2.${TabCardStat.kJsonFileID}   = mainCard.${TabCardHead.kJsonFileID}
           AND sub2.${TabCardStat.kCardGroupKey} = mainCard.${TabCardHead.kGroupKey}
    )
    
    AND NOT EXISTS ( --у карточки нет линков с невыполненым условием
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
                           AND tag.${TabCardTag.kCardID}             < mainCard.${TabCardHead.kCardID} -- Отбираются карточки которые в файле расположены выше
    
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

  /// Выбирает карточку для тестирования
  CardPointer? _selectStudiedCard() {
    if (cardStatList.isEmpty) return null;

    int totalNQuality = 0;

    for (var stat in cardStatList) {
      totalNQuality += (maxQuality - stat.quality);
    }

    final selNQuality = _random.nextInt(totalNQuality + 1);

    int curNQuality = 0;
    int selIndex = 0;
    for (int i = 0; i < cardStatList.length; i++){
      curNQuality += (maxQuality - cardStatList[i].quality);
      if (curNQuality > selNQuality) {
        selIndex = i;
        break;
      }
    }

    final stat = cardStatList[selIndex];
    return CardPointer(stat.jsonFileID, stat.cardID);
  }

  Future<ProcessCardStat> _initStatData(int cardID) async {
    final cardHead = await tabCardHead.getRow(cardID);

    final jsonFileID    = cardHead![TabCardHead.kJsonFileID] as int;
    final cardKey       = cardHead[TabCardHead.kCardKey]     as String;
    final cardGroupKey  = cardHead[TabCardHead.kGroupKey]    as String;

    final id = await tabCardStat.insertRow(jsonFileID: jsonFileID, cardID: cardID, cardKey: cardKey, cardGroupKey: cardGroupKey, quality: maxQuality, date: _curDay);

    final cardStat = ProcessCardStat(statID: id, jsonFileID: jsonFileID, cardID: cardID, cardGroupKey: cardGroupKey, quality: maxQuality);

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