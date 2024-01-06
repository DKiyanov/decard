import 'package:flutter/material.dart';

import 'card_model.dart';
import 'card_sub_widgets.dart';
import 'card_widget.dart';
import 'common.dart';

class CardView extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, CardData card) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => CardView(card: card)));
  }

  final CardData card;
  const CardView({required this.card, Key? key}) : super(key: key);

  @override
  State<CardView> createState() => _CardViewState();
}

class _CardViewState extends State<CardView> {
  late CardParam _cardParam;
  late CardViewController _cardViewController;

  @override
  void initState() {
    super.initState();

    _cardParam = CardParam(widget.card.difficulty, widget.card.stat.quality);
    _cardViewController = CardViewController(widget.card, _cardParam);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(TextConst.txtCardView),
        ),
        body: _cardWidget()
    );
  }

  Widget _cardWidget() {
    return CardWidget(
      card       : widget.card,
      cardParam  : _cardParam,
      controller : _cardViewController,
    );
  }
}
