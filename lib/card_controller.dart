import 'package:collection/collection.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'db.dart';
import 'card_model.dart';
import 'regulator.dart';
import 'package:simple_events/simple_events.dart' as event;
import 'card_sub_widgets.dart';
import 'package:flutter/material.dart';

typedef CardWidgetBuilder = Widget Function(CardData card, CardParam cardParam, CardViewController cardViewController);
typedef OnCardResult = Function(CardData card, CardParam cardParam, bool result, int tryCount, int solveTime, double earned);

class CardKeyInfo {
  final int jsonFileID;
  final int cardID;
  final int bodyNum;
  CardKeyInfo({required this.jsonFileID, required this.cardID, required this.bodyNum});
}

class CardController {
  final DbSource dbSource;
  late Regulator regulator;
  final Future<CardPointer?>? Function()? onSelectNextCard;
  final void Function(int jsonFileID, int cardID)? onSetCard;
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

  CardKeyInfo? _cardKeyInfo;
  CardKeyInfo? get cardKeyInfo => _cardKeyInfo;

  CardViewController? _cardViewController;
  CardViewController? get cardViewController => _cardViewController;

  String? _cardSetError;

  CardParam? _cardParam;
  CardParam? get carCost => _cardParam;

  final onChange = event.SimpleEvent();
  final onAddEarn = event.SimpleEvent<double>();

  void setNoCard() {
    _cardKeyInfo = null;
    _card = null;
    _cardParam = null;
    _cardViewController = null;
    onChange.send();
  }

  /// Sets the current card data
  Future<void> setCard(int jsonFileID, int cardID, {int? bodyNum, CardSetBody setBody = CardSetBody.random, int? startTime}) async {
    try {
      _cardSetError = null;
      _cardKeyInfo  = null;

      _card = await CardData.create(dbSource, regulator, jsonFileID, cardID, bodyNum: bodyNum, setBody: setBody);
      _cardKeyInfo = CardKeyInfo(jsonFileID: jsonFileID, cardID: cardID, bodyNum: _card!.body.bodyNum);

      _cardParam   = CardParam(_card!.difficulty, _card!.stat.quality);

      _cardViewController = CardViewController(_card!, _cardParam!, _onCardResult, startTime);

      onSetCard?.call(_card!.head.jsonFileID, _card!.head.cardID);
    } catch (e) {
      _cardKeyInfo = CardKeyInfo(jsonFileID: jsonFileID, cardID: cardID, bodyNum: bodyNum??CardData.createSelectedBodyNum??0);
      _card = null;
      _cardParam = null;
      _cardViewController = null;
      _cardSetError = 'Карточка содержит ошибку, просмотр не возможен';
      Fluttertoast.showToast(msg: _cardSetError!);
    }
    
    onChange.send();
  }

  Future<bool> setNextCard() async {
    final cardPointer =  (await onSelectNextCard?.call()) ?? (await _selectNextCard());
    if (cardPointer == null) return false;

    setCard(cardPointer.jsonFileID, cardPointer.cardID);
    return true;
  }

  Future<bool> setFirstCard([int? jsonFileID]) async {
    _card = null;

    final cardPointer = await _selectNextCard(jsonFileID);
    if (cardPointer == null) return false;

    await setCard(cardPointer.jsonFileID, cardPointer.cardID);
    return true;
  }

  List<CardPointer>? _cardPointerList; // for _selectNextCard only

  Future<CardPointer?> _selectNextCard([int? jsonFileID]) async {
    if (_cardPointerList == null) {
      _cardPointerList = <CardPointer>[];

      final cardHeadRows = await dbSource.tabCardHead.getAllRows();
      for (var cardHead in cardHeadRows) {
        final jsonFileID = cardHead[TabCardHead.kJsonFileID] as int;
        final cardID     = cardHead[TabCardHead.kCardID] as int;
        _cardPointerList!.add(CardPointer(jsonFileID, cardID));
      }

      _cardPointerList!.sort((a,b) => a.cardID.compareTo(b.cardID));
    }

    if (_card != null) {
      final curCardIndex = _cardPointerList!.indexWhere((cardPointer) => cardPointer.cardID == _card!.head.cardID);
      final curCardPointer = _cardPointerList![curCardIndex];

      if (jsonFileID != null && curCardPointer.jsonFileID != jsonFileID) {
        final cardPointer = _cardPointerList!.firstWhereOrNull((cardPointer) => cardPointer.jsonFileID == jsonFileID);
        return cardPointer;
      }

      final nextCardIndex = curCardIndex + 1;
      if (nextCardIndex >= _cardPointerList!.length) return curCardPointer;

      final nextCardPointer = _cardPointerList![nextCardIndex];

      if (jsonFileID != null && nextCardPointer.jsonFileID != jsonFileID) {
        return curCardPointer;
      }

      return nextCardPointer;
    }

    if (jsonFileID != null) {
      final cardPointer = _cardPointerList!.firstWhereOrNull((cardPointer) => cardPointer.jsonFileID == jsonFileID);
      return cardPointer;
    }

    return _cardPointerList!.first;
  }

  Widget cardListenWidgetBuilder(CardWidgetBuilder builder) {
    return event.EventReceiverWidget(
      builder: (_) {
        if (_cardSetError != null) {
          return Center(child: Text(_cardSetError!, textAlign: TextAlign.center,));
        }
        if (_card == null) return Container();
        return builder.call(_card!, _cardParam!, _cardViewController!);
      },

      events: [onChange],
    );
  }

  Future<void> _onCardResult(CardData card, CardParam cardParam, bool result, int tryCount, int solveTime, double earned) async {
    if (cardParam.noSaveResult) return;

    onAddEarn.send(earned);
    onCardResult?.call(card, cardParam, result, tryCount, solveTime, earned);
  }
}