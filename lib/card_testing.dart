import 'package:decard/view_source.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:simple_events/simple_events.dart';

import 'app_state.dart';
import 'card_demo.dart';
import 'card_widget.dart';
import 'child.dart';
import 'common.dart';

class DeCard extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, Child child) async {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => DeCard(child: child)));
  }

  final Child child;
  const DeCard({required this.child, Key? key}) : super(key: key);

  @override
  State<DeCard> createState() => _DeCardState();
}

class _DeCardState extends State<DeCard> {
  static const keyCardFileID    = 'CardFileID';
  static const keyCardID        = 'CardID';
  static const keyCardBodyNum   = 'CardBodyNum';
  static const keyCardStartTime = 'CardStartTime';

  final cardWidgetKey = GlobalKey<CardWidgetState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(TextConst.txtAppTitle),
              Container(width: 4),
              _earnedBoxWidget(),
            ],
          ),
          actions: [
            if (widget.child.cardController.card != null && widget.child.cardController.card!.body.clue.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: InkWell(
                    onTap: () async {
                      await ViewContent.navigatorPush(context, widget.child.cardController.card!.pacInfo.path, widget.child.cardController.card!.body.clue, TextConst.txtHelp);
                      final percent = (70 * widget.child.cardController.card!.stat.quality / 100).truncate();
                      _setCostMinusPercent(percent);
                    },
                    child: const Icon(Icons.live_help, color: Colors.lime)
                ),
              )
            ],

            if (widget.child.cardController.card != null && widget.child.cardController.card!.head.help.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: InkWell(
                  onTap: () async {
                    await ViewContent.navigatorPush(context, widget.child.cardController.card!.pacInfo.path, widget.child.cardController.card!.head.help, TextConst.txtHelp);
                    final percent = (50 * widget.child.cardController.card!.stat.quality / 100).truncate();
                    _setCostMinusPercent(percent);
                  },
                  child: const Icon(Icons.help)
                ),
              )
            ],

            if (widget.child.cardController.card == null) ...[
              PopupMenuButton<VoidCallback>(
                icon: const Icon(Icons.menu),
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<VoidCallback>(
                      value: () {
                        DeCardDemo.navigatorPush(context, widget.child);
                      },
                      child: Text(TextConst.txtDemo),
                    ),

                    // PopupMenuItem<VoidCallback>(
                    //   value: () {
                    //     appState.selfTest(appState.childList.first);
                    //   },
                    //   child: Text(TextConst.txtAutoTest),
                    // )

                  ];
                },
                onSelected: (value){
                  value.call();
                },
              ),
            ],
          ],
        ),

        body: _body( )
    );
  }

  Widget _earnedBoxWidget() {
    if (appState.appMode == AppMode.demo) return Container();

    return EventReceiverWidget(
      builder: (_) {
        Color? color;
        if (appState.earnController.earnedSeconds > widget.child.regulator.options.minEarnTransferMinutes) {
          color = Colors.green;
        } else {
          color = Colors.grey;
        }

        final earnedBox = Container(
          padding: const EdgeInsets.all(5.0),
          decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: color,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(20))
          ),
          child: Text(getEarnedText(appState.earnController.earnedSeconds)),
        );

        if (appState.earnController.earnedSeconds > widget.child.regulator.options.minEarnTransferMinutes * 60 ) {
          return Row(children: [
            earnedBox,
            IconButton(
              onPressed: appState.earnController.sendEarned,
              icon: const Icon(Icons.send)
            )
          ]);
        } else {
          return earnedBox;
        }
      },
      events: [appState.earnController.onChangeEarn],
    );
  }

  Widget _body( ) {
    if (widget.child.cardController.card == null) {
      return Center(
        child: ElevatedButton(
            onPressed : _startFirstTest,
            child     : Text(TextConst.txtStartTesting)
        ),
      );
    }

    if (appState.appMode == AppMode.testing) return _cardWidget();

    return Container();
  }

  Widget _cardWidget() {
    return EventReceiverWidget(
      builder: (_) {
        if (widget.child.cardController.card == null) return Container();

        return CardWidget(
          key                   : cardWidgetKey,
          card                  : widget.child.cardController.card!,
          onPressSelectNextCard : _selectNextCard,
          demoMode              : false,
        );
      },
      events: [widget.child.cardController.onChange],
    );
  }

  Future<void> _saveSelCard() async {
    final card = widget.child.cardController.card!;
    await appState.prefs.setInt(keyCardFileID   , card.head.jsonFileID);
    await appState.prefs.setInt(keyCardID       , card.head.cardID);
    await appState.prefs.setInt(keyCardBodyNum  , card.body.bodyNum);
    await appState.prefs.setInt(keyCardStartTime, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _selectNextCard() async {
    final ok = await widget.child.cardController.selectNextCard();
    if (ok) {
      await _saveSelCard();
      setState(() {});
    } else {
      Fluttertoast.showToast(msg: TextConst.txtNoCards);
    }
  }

  Future<void> _setTestCard(int jsonFileID, int cardID, int bodyNum, int startTime) async {
    try {
      await widget.child.cardController.setCard(jsonFileID, cardID, bodyNum: bodyNum, startTime : startTime);
      if (widget.child.cardController.card == null) {
        await _selectNextCard();
        return;
      }
      setState(() {});
    } catch (e) {
      await _selectNextCard();
    }
  }

  void _startFirstTest() {
    final cardFileID    = appState.prefs.getInt(keyCardFileID)??-1;
    final cardID        = appState.prefs.getInt(keyCardID)??-1;
    final cardBodyNum   = appState.prefs.getInt(keyCardBodyNum)??0;
    var cardStartTime   = appState.prefs.getInt(keyCardStartTime)??0;

    if (cardStartTime > 0) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(cardStartTime);
      final now = DateTime.now();
      if (now.difference(dateTime).inMinutes >= 90) {
        cardStartTime = 0;
      }
    }

    if (cardFileID >= 0 && cardID >= 0) {
      _setTestCard(cardFileID, cardID, cardBodyNum, cardStartTime);
      return;
    }

    _selectNextCard();
  }

  _setCostMinusPercent(int percents) {
    final cardWidgetState = cardWidgetKey.currentState;
    if (cardWidgetState == null || !cardWidgetState.mounted) return;
    cardWidgetState.setCostMinusPercent(percents);
  }
}
