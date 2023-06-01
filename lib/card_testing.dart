import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:simple_events/simple_events.dart';

import 'app_state.dart';
import 'card_widget.dart';
import 'common.dart';
import 'db.dart';
import 'package:decard/password_input.dart';

class DeCard extends StatefulWidget {
  static Future<Object?> navigatorPushReplacement(BuildContext context) async {
    return Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeCard() ));
  }

  const DeCard({Key? key}) : super(key: key);

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
                  TextConst.txtOptions,

                  if (appState.scanningOnProcess) ...[
                    TextConst.txtDownloadingInProgress,
                  ] else ...[
                    TextConst.txtDownloadNewFiles,
                  ],

                  if (appState.scanErrList.isNotEmpty) ...[
                    TextConst.txtLastDownloadError
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
                if (value == TextConst.txtOptions) {
                  PasswordInput.navigatorPush(context);
                }

                if (value == TextConst.txtDownloadNewFiles) {
                  await appState.scanFileSourceList();
                  if (mounted) {
                    appState.scanErrorsDialog(context);
                  }
                }

                if (value == TextConst.txtLastDownloadError) {
                  if (mounted) appState.scanErrorsDialog(context);
                }

                if (value == TextConst.txtInitDirList){
                  appState.initFileSourceList();
                }
                if (value == TextConst.txtDeleteDB){
                  _deleteDB();
                }
                if (value == TextConst.txtClearDB){
                  _clearDB();
                }

                if (value == TextConst.txtStartTest) {
                  appState.selfTest();
                }
              },
            ),
          ],
        ),

        body: _cardWidget( )
    );
  }

  Future<void> _deleteDB() async {
    await DBProvider.db.deleteDB();
  }

  Future<void> _clearDB() async {
    final db = await DBProvider.db.database;
    await db!.delete(TabSourceFile.tabName);
    await db.delete(TabJsonFile.tabName);
    await db.delete(TabCardStyle.tabName);
    await db.delete(TabCardHead.tabName);
    await db.delete(TabCardBody.tabName);
    await db.delete(TabCardTag.tabName);
    await db.delete(TabCardStat.tabName);
  }

  Future<void> _selectNextCard() async {
    final ok = await appState.cardController.selectNextCard();
    if (!ok) {
      Fluttertoast.showToast(msg: TextConst.txtNoCards);
    } else {
      appState.prefs.setInt(keyCardFileID , appState.cardController.card!.head.jsonFileID);
      appState.prefs.setInt(keyCardID     , appState.cardController.card!.head.cardID);
      appState.prefs.setInt(keyCardBodyNum, appState.cardController.card!.body.bodyNum);
    }
  }

  Future<void> _setTestCard(int jsonFileID, int cardID, int bodyNum) async {
    try {
      await appState.cardController.setCard(jsonFileID, cardID, bodyNum: bodyNum);
    } catch (e) {
      _selectNextCard();
    }

  }

  Widget _earnedBoxWidget() {
    return EventReceiverWidget(
      builder: (_) {
        Color? color;
        if (appState.earned > appState.minEarnValue) {
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
          child: Text(appState.earned.toStringAsFixed(1)),
        );

        if (appState.earned > appState.minEarnValue) {
          return Row(children: [
            earnedBox,
            IconButton(
              onPressed: appState.sendEarned,
              icon: const Icon(Icons.send)
            )
          ]);
        } else {
          return earnedBox;
        }
      },
      events: [appState.onChangeEarn],
    );
  }

  Widget _cardWidget( ) {
    return EventReceiverWidget(
      builder: (_) {
        return __cardWidget();
      },
      events: [appState.cardController.onChange],
    );
  }

  Widget __cardWidget() {
    if (appState.cardController.card == null) {
      return Center(
        child: ElevatedButton(
            onPressed : _startFirstTest,
            child     : Text(TextConst.txtStartTesting)
        ),
      );
    }

    return CardWidget(
      card                  : appState.cardController.card!,
      onPressSelectNextCard : _selectNextCard,
    );
  }

  void _startFirstTest() {
    // final cardFileID  = appState.prefs.getInt(keyCardFileID)??-1;
    // final cardID      = appState.prefs.getInt(keyCardID)??-1;
    // final cardBodyNum = appState.prefs.getInt(keyCardBodyNum)??0;

    // if (cardFileID >= 0 && cardID >= 0) {
    //   _setTestCard(cardFileID, cardID, cardBodyNum);
    //   return;
    // }

    _selectNextCard();
  }
}
