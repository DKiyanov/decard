import 'package:decard/card_set_list.dart';
import 'package:flutter/material.dart';
import 'package:simple_events/simple_events.dart';

import 'card_navigator.dart';
import 'card_widget.dart';
import 'child.dart';
import 'common.dart';
import 'pack_info_widget.dart';

class DeCardDemo extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, Child child, {String fileGuid = '', bool onlyThatFile = false}) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => DeCardDemo(child: child, fileGuid: fileGuid, onlyThatFile: onlyThatFile)));
  }

  final Child child;
  final String fileGuid;
  final bool onlyThatFile;

  const DeCardDemo({
    required this.child,
    this.fileGuid = '',
    this.onlyThatFile = false,
    Key? key
  }) : super(key: key);

  @override
  State<DeCardDemo> createState() => _DeCardDemoState();
}

class _DeCardDemoState extends State<DeCardDemo> {
  @override
  Widget build(BuildContext context) {
    final card = widget.child.cardController.card;

    return Scaffold(
        appBar: AppBar(
          title: Text(TextConst.txtAppTitle),
          actions: [
            if (card != null) ...[
              IconButton(
                  onPressed: (){
                    CardSetList.navigatorPush(context, widget.child, fileGuid: card.pacInfo.guid, onlyThatFile: true, card: card);
                  },
                  icon: const Icon(Icons.tune)
              ),

              IconButton(
                  onPressed: ()=>packInfoDisplay(context, card.pacInfo),
                  icon: const Icon(Icons.info_outline)
              ),
            ]
          ],
        ),
        body: _body()
    );
  }

  Widget _body() {
    return Column(children: [
      CardNavigator(child: widget.child),
      Expanded(child: _cardWidget()),
    ]);
  }

  Widget _cardWidget() {
    return EventReceiverWidget(
      builder: (_) {
        if (widget.child.cardController.card == null) return Container();

        return CardWidget(
          card: widget.child.cardController.card!,
          onPressSelectNextCard: () {},
          demoMode: true,
        );
      },
      events: [widget.child.cardController.onChange],
    );
  }
}
