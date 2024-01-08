//import 'package:decard/app_state.dart';
//import 'package:decard/card_set_list.dart';
import 'package:flutter/material.dart';
//import 'package:simple_events/simple_events.dart';

//import 'card_model.dart';
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
  bool _isStarting = true;
  late CardNavigatorData _cardNavigatorData;

//  CardData? get _card => widget.child.cardController.card;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    _cardNavigatorData = CardNavigatorData(widget.child.dbSource);
    await _cardNavigatorData.setData();

    setState(() {
      _isStarting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(TextConst.txtLoading),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(TextConst.txtAppTitle),
          actions: [
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
      CardNavigator(
        cardController: widget.child.cardController,
        cardNavigatorData: _cardNavigatorData,
      ),
      Expanded(child: _cardWidget()),
    ]);
  }

  Widget _cardWidget() {
    return widget.child.cardController.cardListenWidgetBuilder((card, cardParam, cardViewController) {
      cardParam.noSaveResult = true;

      return CardWidget(
        key        : ValueKey(card),
        card       : card,
        cardParam  : cardParam,
        controller : cardViewController,
      );
    });
  }
}
