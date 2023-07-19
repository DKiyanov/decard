import 'package:decard/card_set_list.dart';
import 'package:flutter/material.dart';
import 'package:simple_events/simple_events.dart';

import 'card_model.dart';
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

  CardData? get _card => widget.child.cardController.card;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        appBar: AppBar(
          title: Text(TextConst.txtAppTitle),
          actions: [
            IconButton(
                onPressed: (){
                  if (_card == null) return;
                  CardSetList.navigatorPush(context, widget.child, fileGuid: _card!.pacInfo.guid, onlyThatFile: true, card: _card);
                },

                icon: EventReceiverWidget(
                  builder: (BuildContext context) {
                     return Icon(Icons.tune, color: _card?.head.regulatorSetIndex != null ? Colors.red : null);
                  },
                  events: [widget.child.cardController.onChange]
                ),
            ),

            IconButton(
              onPressed: (){
                final card = widget.child.cardController.card;
                if (card == null) return;
                packInfoDisplay(context, card.pacInfo);
              },
              icon: const Icon(Icons.info_outline)
            ),
          ]
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
          card     : widget.child.cardController.card!,
          demoMode : true,
        );
      },
      events: [widget.child.cardController.onChange],
    );
  }
}
