import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:simple_events/simple_events.dart';

import 'app_state.dart';
import 'card_navigator.dart';
import 'card_widget.dart';
import 'child.dart';
import 'common.dart';

class DeCard extends StatefulWidget {
  final Child child;
  const DeCard({required this.child, Key? key}) : super(key: key);

  @override
  State<DeCard> createState() => _DeCardState();
}

class _DeCardState extends State<DeCard> {
  static const keyCardFileID  = 'CardFileID';
  static const keyCardID      = 'CardID';
  static const keyCardBodyNum = 'CardBodyNum';

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
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu),
              itemBuilder: (context) {
                return [
                  // TextConst.txtOptions,

                  // if (appState.scanningOnProcess) ...[
                  //   TextConst.txtDownloadingInProgress,
                  // ] else ...[
                  //   TextConst.txtDownloadNewFiles,
                  // ],
                  //
                  // if (appState.scanErrList.isNotEmpty) ...[
                  //   TextConst.txtLastDownloadError
                  // ],

                  if (appState.appMode == AppMode.testing) ...[
                    TextConst.txtDemo,
                  ],

                  if (appState.appMode == AppMode.demo) ...[
                    TextConst.txtTesting,
                  ],

                  // TextConst.txtStartTest,

                  // TextConst.txtInitDirList,
                  // TextConst.txtClearDB,
                  // TextConst.txtDeleteDB,
                ].map<PopupMenuItem<String>>((value) => PopupMenuItem<String>(
                  value: value,
                  child: Text(value),
                )).toList();
              },
              onSelected: (value) async {
                // if (value == TextConst.txtOptions) {
                //   PasswordInput.navigatorPush(context);
                // }

                // if (value == TextConst.txtDownloadNewFiles) {
                //   await appState.scanFileSourceList();
                //   if (mounted) {
                //     appState.scanErrorsDialog(context);
                //   }
                // }

                // if (value == TextConst.txtLastDownloadError) {
                //   if (mounted) appState.scanErrorsDialog(context);
                // }
                //
                // if (value == TextConst.txtInitDirList){
                //   appState.initFileSourceList();
                // }
                // if (value == TextConst.txtDeleteDB){
                //   _deleteDB();
                // }
                // if (value == TextConst.txtClearDB){
                //   _clearDB();
                // }

                // if (value == TextConst.txtStartTest) {
                //   appState.selfTest();
                // }

                if (value == TextConst.txtDemo) {
                  setState(() {
                    appState.appMode = AppMode.demo;
                  });
                }

                if (value == TextConst.txtTesting) {
                  appState.appMode = AppMode.testing;
                  _startFirstTest();
                }
              },
            ),
          ],
        ),

        body: _body( )
    );
  }

  // Future<void> _deleteDB() async {
  //   await DecardDB.db.deleteDB();
  // }
  //
  // Future<void> _clearDB() async {
  //   final db = await DecardDB.db.database;
  //   await db!.delete(TabSourceFile.tabName);
  //   await db.delete(TabJsonFile.tabName);
  //   await db.delete(TabCardStyle.tabName);
  //   await db.delete(TabCardHead.tabName);
  //   await db.delete(TabCardBody.tabName);
  //   await db.delete(TabCardTag.tabName);
  //   await db.delete(TabCardStat.tabName);
  // }

  Future<void> _selectNextCard() async {
    final ok = await widget.child.cardController.selectNextCard();
    if (!ok) {
      Fluttertoast.showToast(msg: TextConst.txtNoCards);
    } else {
      appState.prefs.setInt(keyCardFileID , widget.child.cardController.card!.head.jsonFileID);
      appState.prefs.setInt(keyCardID     , widget.child.cardController.card!.head.cardID);
      appState.prefs.setInt(keyCardBodyNum, widget.child.cardController.card!.body.bodyNum);
    }
  }

  Future<void> _setTestCard(int jsonFileID, int cardID, int bodyNum) async {
    try {
      await widget.child.cardController.setCard(jsonFileID, cardID, bodyNum: bodyNum);
      setState(() {});
    } catch (e) {
      _selectNextCard();
    }

  }

  Widget _earnedBoxWidget() {
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

  Widget _cardNavigator() {
    return CardNavigator(child: widget.child,);
  }

  Widget _body( ) {
    if (appState.appMode == AppMode.demo) {
      return Column(children: [
        _cardNavigator(),
        Expanded(child: _cardWidget()),
      ]);
    }

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
          card                  : widget.child.cardController.card!,
          onPressSelectNextCard : _selectNextCard,
          demoMode              : appState.appMode == AppMode.demo,
        );
      },
      events: [widget.child.cardController.onChange],
    );
  }

  void _startFirstTest() {
    final cardFileID  = appState.prefs.getInt(keyCardFileID)??-1;
    final cardID      = appState.prefs.getInt(keyCardID)??-1;
    final cardBodyNum = appState.prefs.getInt(keyCardBodyNum)??0;

    if (cardFileID >= 0 && cardID >= 0) {
      _setTestCard(cardFileID, cardID, cardBodyNum);
      return;
    }

    _selectNextCard().then((value) => setState(() {}));
  }
}
