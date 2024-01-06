import 'dart:async';

import 'regulator.dart';
import 'package:flutter/material.dart';

import 'card_model.dart';
import 'card_sub_widgets.dart';
import 'common.dart';
import 'context_extension.dart';
import 'package:simple_events/simple_events.dart' as event;

String _costToStr(int cost){
  return '$cost';
}

class _CostBox extends StatelessWidget {
  final int cost;
  final Color color;
  const _CostBox(this.cost, this.color, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final costStr = _costToStr(cost);

    if (costStr.length <= 2) {
      final size = context.scale * 25;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: color,
          ),
          shape: BoxShape.circle,
//            borderRadius: const BorderRadius.all(Radius.circular(20))
        ),
        child: Align(child: Text(costStr)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5.0),
      decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: color,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(20))
      ),
      child: Text(costStr),
    );
  }
}

class _CostPanelWarp extends StatelessWidget {
  final String text;
  final Widget child;

  const _CostPanelWarp(this.text, this.child, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColorDark,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Text(text),
            Container(width: 4),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class CostPanel extends StatelessWidget {
  final CardViewController controller;

  const CostPanel({required this.controller, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (controller.result == null) {
      if (controller.cardParam.duration == 0 || controller.cardParam.cost == controller.cardParam.lowCost) {
        return _CostPanelSimple(cardParam: controller.cardParam);
      } else {
        return _CostPanelWithTimer(controller: controller);
      }
    } else {
      return _CostPanelResult(controller: controller);
    }
  }
}

class _CostPanelSimple extends StatelessWidget {
  final CardParam cardParam;
  const _CostPanelSimple({required this.cardParam, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final panelChild = Row(children: [
      _CostBox(cardParam.cost, Colors.lightGreen),
      if (cardParam.penalty != 0) ...[
        Expanded(child: Container()),
        _CostBox( - cardParam.penalty, Colors.deepOrangeAccent),
      ]
    ]);

    return _CostPanelWarp(TextConst.txtCost, panelChild);
  }
}

/// панель отображающая стоимость решения карточки, штраф за не верной решение
/// анимация изменения стоимости от задержки при решении
class _CostPanelWithTimer extends StatefulWidget {
  final CardViewController controller;

  const _CostPanelWithTimer({required this.controller, Key? key}) : super(key: key);

  @override
  State<_CostPanelWithTimer> createState() => _CostPanelWithTimerState();
}

class _CostPanelWithTimerState extends State<_CostPanelWithTimer> {
  Timer?    _costTimer;
  double    _timeProgress = 0; // процент потраченого времени
  int       _costDuration = 0; // длительность в мимлисекундах
  DateTime? _startTime;

  event.Listener? onAnswerListener;
  event.Listener? onCostMinusPercent;

  CardParam get cardParam => widget.controller.cardParam;

  @override
  void initState() {
    super.initState();

    if (widget.controller.startTime == 0) {
      _startTime = DateTime.now();
    } else {
      _startTime = DateTime.fromMillisecondsSinceEpoch(widget.controller.startTime);
    }

    onAnswerListener = widget.controller.onAnswer.subscribe((listener, data) {
      _stopCostTimer();
    });

    onCostMinusPercent = widget.controller.onCostMinusPercent.subscribe((listener, data) {
      if (!mounted) return;
      setState(() {
        _calcCostValue();
      });
    });

    widget.controller.costValue = cardParam.cost.toDouble();
    _costDuration = cardParam.duration * 1000;
    _initCostTimer();
  }

  @override
  void dispose() {
    onAnswerListener?.dispose();
    onCostMinusPercent?.dispose();
    super.dispose();
  }

  void _stopCostTimer(){
    if (_costTimer != null) {
      _costTimer!.cancel();
      _costTimer = null;
    }
  }

  void _initCostTimer() {
    _stopCostTimer();

    _costTimer = Timer.periodic( const Duration(milliseconds: 100), (timer){
      if (!mounted) return;

      setState(() {
        _calcCostValue();

        if (widget.controller.costValue <= cardParam.lowCost) {
          widget.controller.costValue = cardParam.lowCost.toDouble();
          _timeProgress = 1;
          timer.cancel();
        }

      });
    });
  }

  void _calcCostValue() {
    if (_costDuration > 0) {
      final time = DateTime.now().difference(_startTime!).inMilliseconds;
      _timeProgress = (time / _costDuration)  + (widget.controller.costMinusPercent / 100);
      if (_timeProgress > 1) {
        _timeProgress = 1;
      }

      widget.controller.costValue = cardParam.cost - (cardParam.cost - cardParam.lowCost) * _timeProgress;

      if (time >= _costDuration) {
        widget.controller.costValue = cardParam.lowCost.toDouble();
      }
    } else {
      widget.controller.costValue = cardParam.cost - (cardParam.cost - cardParam.lowCost) * (widget.controller.costMinusPercent / 100);
    }

    if (widget.controller.costValue < cardParam.lowCost) {
      widget.controller.costValue = cardParam.lowCost.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelChild = Row(children: [
      _CostBox(cardParam.cost, Colors.green),
      Container(width: 4),
      Expanded(child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: LinearProgressIndicator(
                backgroundColor: Colors.green,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightGreen),
                value: _timeProgress,
                minHeight: 18 * context.scale,
              ),
            ),
            Text(_costToStr(widget.controller.costValue.truncate())),
          ]
      )),
      Container(width: 4),
      _CostBox(cardParam.lowCost, Colors.lightGreen),
      Container(width: 4),
      _CostBox(cardParam.penalty, Colors.deepOrangeAccent),
    ]);

    return _CostPanelWarp(TextConst.txtCost, panelChild);
  }
}

class _CostPanelResult extends StatelessWidget {
  final CardViewController controller;

  const _CostPanelResult({required this.controller, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (controller.result == null) return Container();

    String panelText;
    Widget panelChild;

    if (controller.result!) {
      panelText = TextConst.txtEarned;

      panelChild = Row(children: [ _CostBox(controller.costValue.truncate(), Colors.lightGreen) ]);
    } else {
      panelText = TextConst.txtPenalty;

      if (controller.cardParam.penalty != 0) {
        panelChild = Row(children: [ _CostBox( - controller.cardParam.penalty, Colors.deepOrangeAccent) ]);
      } else {
        panelChild = Row(children: const [ _CostBox(0, Colors.yellow) ]);
      }
    }

    return _CostPanelWarp(panelText, panelChild);
  }
}

class CostPanelDemo extends StatelessWidget {
  final CardData card;
  final RegDifficulty difficulty;
  final List<Widget>?  actions;
  const CostPanelDemo({required this.card, required this.difficulty, this.actions, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget panelChild = Row(children: [
      _CostBox(difficulty.maxCost, Colors.green),
      Container(width: 4),
      _CostBox(difficulty.minCost, Colors.lightGreen),
      Container(width: 4),
      _CostBox(-difficulty.maxPenalty, Colors.deepOrangeAccent),
      Expanded(child: Container()),

      if (actions != null) ...actions!,

    ]);

    return _CostPanelWarp(TextConst.txtCost, panelChild);
  }

}