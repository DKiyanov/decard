import 'package:flutter/material.dart';

import 'card_model.dart';
import 'card_widget.dart';
import 'common.dart';

class CardView extends StatelessWidget {
  static Future<Object?> navigatorPush(BuildContext context, CardData card) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => CardView(card: card)));
  }

  final CardData card;
  const CardView({required this.card, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(TextConst.txtCardView),
        ),
        body: CardWidget(
          card     : card,
          demoMode : true,
        )
    );
  }
}
