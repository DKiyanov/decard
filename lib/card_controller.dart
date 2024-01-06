import 'db.dart';
import 'card_model.dart';
import 'regulator.dart';
import 'package:simple_events/simple_events.dart' as event;
import 'card_sub_widgets.dart';
import 'package:flutter/material.dart';

typedef CardWidgetBuilder = Widget Function(CardData card, CardParam cardParam, CardViewController cardViewController);
typedef OnCardResult = Function(CardData card, CardParam cardParam, bool result, int tryCount, int solveTime, double earned);

class CardController {
  final DbSource dbSource;
  late Regulator regulator;
  final Future<CardPointer?>? Function()? onSelectNextCard;
  final void Function(int cardID)? onSetCard;
  final OnCardResult? onCardResult;

  CardController({required this.dbSource, Regulator? regulator, this.onSelectNextCard, this.onSetCard, this.onCardResult}) {
    if (regulator != null) {
      this.regulator = regulator;
    } else {
      this.regulator = Regulator(options: RegOptions(), cardSetList: [], difficultyList: []);
      this.regulator.fillDifficultyLevels();
    }
  }

  CardData? _card;
  CardData? get card => _card;

  CardViewController? _cardViewController;
  CardViewController? get cardViewController => _cardViewController;

  CardParam? _cardParam;
  CardParam? get carCost => _cardParam;

  final onChange = event.SimpleEvent();
  final onAddEarn = event.SimpleEvent<double>();

  void setNoCard() {
    _card = null;
    _cardParam = null;
    _cardViewController = null;
    onChange.send();
  }

  /// Sets the current card data
  Future<void> setCard(int jsonFileID, int cardID, {int? bodyNum, CardSetBody setBody = CardSetBody.random, int? startTime}) async {
    _card = await CardData.create(dbSource, regulator, jsonFileID, cardID, bodyNum: bodyNum, setBody: setBody);

    _cardParam   = CardParam(_card!.difficulty, _card!.stat.quality);

    _cardViewController = CardViewController(_card!, _cardParam!, _onCardResult, startTime);

    onSetCard?.call(_card!.head.cardID);

    onChange.send();
  }

  Future<bool> setNextCard() async {
    final cardPointer =  (await onSelectNextCard?.call()) ?? (await _selectNextCard());
    if (cardPointer == null) return false;

    setCard(cardPointer.jsonFileID, cardPointer.cardID);
    return true;
  }

  Future<CardPointer?> _selectNextCard() async {
    Map<String, dynamic> row;

    final rows = await dbSource.tabCardHead.getAllRows();
    if (rows.isEmpty) return null;

    if (_card == null) {
      row = rows[0];
    } else {
      final index = rows.indexWhere((cardHead) => cardHead[TabCardHead.kCardID] == _card!.head.cardID) + 1;
      if (index < rows.length) {
        row = rows[index];
      } else {
        row = rows[0];
      }
    }

    final jsonFileID = row[TabCardHead.kJsonFileID] as int;
    final cardID     = row[TabCardHead.kCardID] as int;

    return CardPointer(jsonFileID, cardID);
  }

  Widget cardListenWidgetBuilder(CardWidgetBuilder builder) {
    return event.EventReceiverWidget(
      builder: (_) {
        if (_card == null) return Container();
        return builder.call(_card!, _cardParam!, _cardViewController!);
      },

      events: [onChange],
    );
  }

  Future<void> _onCardResult(CardData card, CardParam cardParam, bool result, int tryCount, int solveTime, double earned) async {
    onAddEarn.send(earned);
    onCardResult?.call(card, cardParam, result, tryCount, solveTime, earned);
  }
}