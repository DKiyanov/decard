import 'package:decard/context_extension.dart';
import 'package:decard/simple_menu.dart';
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
  bool helpAvailability = false;

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
                      if (!helpAvailability) return;
                      await ViewContent.navigatorPush(context, widget.child.cardController.card!.pacInfo.path, widget.child.cardController.card!.body.clue, TextConst.txtHelp);
                      final percent = (70 * widget.child.cardController.card!.stat.quality / 100).truncate();
                      _setCostMinusPercent(percent);
                    },
                    child: Icon(Icons.live_help, color: helpAvailability? Colors.lime : Colors.grey)
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
              popupMenu(
                  icon: const Icon(Icons.menu),
                  menuItemList: [
                    SimpleMenuItem(
                        child: Text(TextConst.txtDemo),
                        onPress: () {
                          DeCardDemo.navigatorPush(context, widget.child);
                        }
                    ),

                    // SimpleMenuItem(
                    //     child: Text(TextConst.txtAutoTest),
                    //     onPress: () {
                    //       appState.selfTest(appState.childList.first);
                    //     }
                    // ),

                  ]
              ),
            ],
          ],
        ),

        body: _body( )
    );
  }

  Widget _earnedBoxWidget() {
    if (appState.appMode == AppMode.demo) return Container();

    final verticalPadding = inLimit( lineValue( context.scale, 1, 5, 1.9, 0), low: 0, high : 5);

    return EventReceiverWidget(
      builder: (_) {
        Color? color;
        if (appState.earnController.earnedSeconds > widget.child.regulator.options.minEarnTransferMinutes) {
          color = Colors.green;
        } else {
          color = Colors.grey;
        }

        final earnedBox = Container(
          padding: EdgeInsets.only(left: 5, right: 5, top: verticalPadding, bottom: verticalPadding),
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
    helpAvailability = false;
    final ok = await widget.child.cardController.selectNextCard();
    if (ok) {
      afterSetCard();
      await _saveSelCard();
      setState(() {});
    } else {
      Fluttertoast.showToast(msg: TextConst.txtNoCards);
    }
  }

  void afterSetCard() {
    final seconds = 10 + (widget.child.cardController.card!.stat.quality * 50 / 100).round();
    Future.delayed(Duration(seconds: seconds), (){
      setState((){
        helpAvailability = true;
      });
    });
  }

  Future<void> _setTestCard(int jsonFileID, int cardID, int bodyNum, int startTime) async {
    try {
      await widget.child.cardController.setCard(jsonFileID, cardID, bodyNum: bodyNum, startTime : startTime);
      if (widget.child.cardController.card == null) {
        await _selectNextCard();
        return;
      }
      afterSetCard();
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
