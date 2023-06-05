import 'dart:math';

import 'package:decard/regulator.dart';
import 'package:sqflite/sqflite.dart';
import 'card_controller.dart';
import 'card_model.dart';
import 'common.dart';
import 'db.dart';

class Child{
  final String childDir;

  late Regulator regulator;

  late Database db;
  late DbSource dbSource;

  late ProcessCardController processCardController;
  late CardController cardController;

  Child(this.childDir);

  Future<void> init() async {
    db = (await DBProvider.db.database)!;
    dbSource = DbSource(db);

    regulator = await Regulator.fromFile('$childDir/regulator.json');

    processCardController = ProcessCardController(db, regulator, dbSource.tabCardStat, dbSource.tabCardHead);
    await processCardController.init();

    cardController = CardController(
      dbSource             : dbSource,
      processCardController: processCardController,
    );

    cardController.onAddEarn.subscribe((listener, earn){
      addEarn(earn!);
    });

  }

  void addEarn(double earn){
    _earned += earn;
    prefs.setDouble(_keyEarned, _earned);
    onChangeEarn.send();
  }

  Future<void> _sendEstimateIntent(int minuteCount) async {
    await sendBroadcast(
      BroadcastMessage(
          name: _keyAddEstimate,
          data: {
            "CoinSourceName" : _coinSourceName,
            "CoinType"       : _keyCoinTypeMinute,
            "CoinCount"      : minuteCount,
          }
      ),
    );
  }

  /// Рассылка уведомлений о зароботке
  Future<void> sendEarned() async {
    final minuteCount = _earned.truncate();

    _sendEstimateIntent(minuteCount);

    _earned = _earned - minuteCount;
    await prefs.setDouble(_keyEarned, _earned);

    onChangeEarn.send();
  }

  /// Выгрузка статистики
  Future<void> uploadStat() async {
//     if (uploadStatUrl == null) return;
//
// //    final fdt = DateTime.fromMillisecondsSinceEpoch(_lastUploadStatDT);
//     final ndt = DateTime.now();
//
//     // в результате должна получиться строка json
//     //
//     // данные должны быть за период с последней выгрузки по текущий момент
//     // данные содержат:
//     //   статистику за период:
//     //     сколько карточек решено:
//     //       правильно
//     //       не правильно
//     //     общее затраченное время
//     //   текущее состояние по пакететам:
//     //     время изучения (кол-во дней от даты начала)
//     //     затраченное время (суммарное время по карточкам)
//     //     сколько картоек изучено
//     //     сколько осталось
//     //     процен изучения
//     //     сколько карточек в активном изучении
//
//     final Map<String, dynamic> map = {};
//
//
//     final jsonStr = jsonEncode(map);
//     final listInt = jsonStr.codeUnits;
//     final bytes = Uint8List.fromList(listInt);
//
//     String fileName = ndt.toIso8601String();
//     fileName.replaceAll(':', '-');
//
//     uploadData(uploadStatUrl!, '$fileName.json', bytes);
//
//     _lastUploadStatDT = ndt.millisecondsSinceEpoch;
//     prefs.setInt(_keyLastUploadStatDT, _lastUploadStatDT);
  }

  /// testing and debugging the card selection algorithm
  Future<void> selfTest() async {
    const int daysCount = 100;
    const int maxCountTestPerDay = 100;
    const int speed = 20; // the number of shows for great memorization

    DateTime curDate = DateTime.now();

    final random = Random();

    await dbSource.tabCardStat.clear();
    await processCardController.init();

    final testCardController = CardController(
      dbSource: dbSource,
      processCardController: processCardController,
    );

    print('tstres start');

    for( var dayNum = 1 ; dayNum <= daysCount; dayNum++ ) {
      curDate = curDate.add(const Duration(days: 1));
      processCardController.setTestDate(curDate);

      final testsCount =  random.nextInt(maxCountTestPerDay);

      for( var testNum = 1 ; testNum <= testsCount; testNum++ ) {
        final cardSelected = await testCardController.selectNextCard();
        if (!cardSelected) return;

        final rnd = random.nextInt(100);
        bool result = false;

        // The probability of a correct answer increases as the number of tests increases
        if (testCardController.card!.stat.testsCount < speed) {
          result = rnd <= 100 * ( testCardController.card!.stat.testsCount / speed );
        } else {
          result = rnd <= 98;
        }

        await processCardController.registerResult(testCardController.card!.head.jsonFileID, testCardController.card!.head.cardID, result);

        final statData = await processCardController.getStatData(testCardController.card!.head.cardID);
        final cardStat = CardStat.fromMap(statData!);

        print('tstres; date ; ${dateToInt(curDate)}; cardKey ; ${testCardController.card!.head.cardKey}; result ; $result; testsCount ; ${cardStat.testsCount}; quality ; ${cardStat.quality}');
      }

    }

    print('tstres finish');
  }
}