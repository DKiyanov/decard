import 'dart:convert';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'simple_menu.dart';
import 'text_constructor/text_constructor.dart';
import 'text_constructor/word_panel_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'card_controller.dart';
import 'card_model.dart';
import 'common.dart';
import 'context_extension.dart';
import 'decardj.dart';
import 'media_widgets.dart';
import 'package:simple_events/simple_events.dart' as event;

class CardViewController {
  final CardData card;
  final CardParam cardParam;
  final OnCardResult? onResult;

  CardViewController(this.card, this.cardParam, [this.onResult, int? startTime]) {
    if (startTime != null) {
      this.startTime = startTime;
    } else {
      this.startTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  double costValue = 0; // заработанное
  late int startTime = 0;

  int    _costMinusPercent = 0; // уменьшение заработаного
  int get costMinusPercent => _costMinusPercent;
  final _onCostMinusPercent = event.PrivateEvent();
  event.EventBase get onCostMinusPercent => _onCostMinusPercent.event;

  bool? _result;
  bool? get result => _result;

  final answerValues = <String>[];
  final answerVariantList = <String>[];

  final multiSelectAnswerOk = event.SimpleEvent();

  final _onAnswer = event.PrivateEvent<bool>();
  event.EventBase<bool> get onAnswer => _onAnswer.event;

  void setResult(bool result, int tryCount){
    _result = result;
    _onAnswer.send(result);
    final solveTime = DateTime.now().millisecondsSinceEpoch - startTime;

    double earned = result? costValue : - cardParam.penalty.toDouble();

    onResult?.call(card, cardParam, result, tryCount, solveTime, earned);
  }

  void setCostMinusPercent(int percent) {
    if (_costMinusPercent < percent) {
      _costMinusPercent = percent;
      _onCostMinusPercent.send();
    }
  }
}

class ValueWidget extends StatelessWidget {
  final CardData card;
  final String str;
  const ValueWidget(this.card, this.str, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (str.isEmpty) return Container();
    if (str.indexOf(DjfCardStyle.buttonImagePrefix) == 0) {
      final imagePath = str.substring(DjfCardStyle.buttonImagePrefix.length);
      final fileUrl = FileExt.getFileUrl(card, imagePath)??imagePath;

      var maxWidth = double.infinity;
      var maxHeight = double.infinity;

      if (card.style.buttonImageWidth > 0) {
        maxWidth = card.style.buttonImageWidth.toDouble();
      }

      if (card.style.buttonImageHeight > 0) {
        maxHeight = card.style.buttonImageHeight.toDouble();
      }

      return LimitedBox(
          maxWidth  : maxWidth,
          maxHeight : maxHeight,
          child     : imageFromUrl(fileUrl)
      );
    }

    // Serif - in this font, the letters "I" and "l" look different, it is important
    return Text(str, style: const TextStyle(fontFamily: 'Serif'));
  }
}

class CardQuestion extends StatelessWidget {
  final CardData card;

  const CardQuestion({required this.card, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final widgetList = <Widget>[];

    for (var source in card.body.questionData) {

      if (source.type == FileExt.contentImage) {
        final fileUrl = _getFileUrl(source.data);
        final maxHeight = context.screenSize.height * card.style.imageMaxHeight / 100;

        widgetList.add(
            LimitedBox(maxHeight: maxHeight, child: imageFromUrl(fileUrl))
        );
      }

      if (source.type == FileExt.contentAudio) {
        final fileUrl = _getFileUrl(source.data);
        widgetList.add(
          audioPanelFromUrl(fileUrl, ValueKey(card.head.cardKey)),
        );
      }

      if (source.type == FileExt.contentText) {
        widgetList.add(
          AutoSizeText(
            source.data,
            style: TextStyle(
                fontSize: context.textTheme.headlineMedium!.fontSize),
            textAlign: TextAlign.center,
          ),
        );
      }

      if (source.type == FileExt.contentHtml) {
        widgetList.add(
          _htmlViewer(source.data),
        );
      }

      if (source.type == FileExt.contentMarkdown) {
        widgetList.add(
            _markdownViewer(source.data)
        );
      }

      if (source.type == FileExt.contentTextConstructor) {
        widgetList.add(
            _textConstructor(source.data)
        );
      }
    }

    return Column(children: widgetList);
  }

  Widget _htmlViewer(String html) {
    final newHtml = FileExt.prepareHtml(card, html);
    return htmlView(newHtml, card.pacInfo.sourceDir);
  }

  Widget _markdownViewer(String markdown) {
    final newMarkdown = FileExt.prepareMarkdown(card, markdown);
    return MarkdownBody(data: newMarkdown);
  }

  Widget _textConstructor(String jsonStr) {
    final textConstructor = TextConstructorData.fromMap(jsonDecode(jsonStr));

    return TextConstructorWidget(
      textConstructor  : textConstructor,
      onPrepareFileUrl : _getFileUrl,
      randomPercent    : 0,
    );
  }

  String _getFileUrl(String fileName) {
    return FileExt.getFileUrl(card, fileName)??fileName;
  }
}

class AnswerInput extends StatefulWidget {
  final CardViewController controller;

  const AnswerInput({required this.controller, Key? key}) : super(key: key);

  @override
  State<AnswerInput> createState() => _AnswerInputState();

  static Alignment getAnswerAlignment(CardData card) {
    var alignment = Alignment.center;

    switch(card.style.answerVariantAlign) {
      case TextAlign.left:
        alignment = Alignment.centerLeft;
        break;
      case TextAlign.right:
        alignment = Alignment.centerRight;
        break;
      default:
        alignment = Alignment.center;
    }

    return alignment;
  }
}

class _AnswerInputState extends State<AnswerInput> {
  final _random = Random();
  final _inputController = TextEditingController(); // Для полей ввода

  CardData get card => widget.controller.card;
  CardParam get cardParam => widget.controller.cardParam;
  
  List<String> get _answerVariantList => widget.controller.answerVariantList; // список вариантов ответов
  List<String> get _answerValues => widget.controller.answerValues; // Выбранные значения

  int _tryCount = 0;

  event.Listener?  _onMultiSelectAnswerOkListener;

  void _prepareAnswerVariantList() {
    // списку из body отдаётся предпочтение
    _answerVariantList.clear();
    _answerVariantList.addAll(card.style.answerVariantList);

    // выдёргиваем из списка лишние варианты так чтоб полчился список нужного размера
    if (card.style.answerVariantCount > card.body.answerList.length && _answerVariantList.length > card.style.answerVariantCount){
      while (_answerVariantList.length > card.style.answerVariantCount) {
        final rndIndex = _random.nextInt(_answerVariantList.length);
        final variant = _answerVariantList[rndIndex];
        if (!card.body.answerList.contains(variant)) {
          _answerVariantList.removeAt(rndIndex);
        }
      }
    }

    if (card.style.answerVariantListRandomize) {
      // перемешиваем список в случайном порядке
      _answerVariantList.shuffle(_random);
    }
  }

  @override
  void initState() {
    super.initState();

    _onMultiSelectAnswerOkListener = widget.controller.multiSelectAnswerOk.subscribe((listener, data) {
      _onMultiSelectAnswer();
    });

    _prepareAnswerVariantList();
  }

  @override
  void dispose() {
    _onMultiSelectAnswerOkListener?.dispose();

    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (card.body.questionData.any((source) => source.type == FileExt.contentTextConstructor)) {
      return Container();
    }

    if (card.style.answerVariantMultiSel) {
      return _getInputWidget();
    }

    return _getInputWidget();
  }

  Widget _getInputWidget() {
    final alignment = AnswerInput.getAnswerAlignment(card);

    final answerInputMode = card.style.answerInputMode;
//    const answerInputMode = AnswerInputMode.widgetKeyboard; // for debug

    // Поле ввода
    if ( answerInputMode == AnswerInputMode.input    ||
        answerInputMode == AnswerInputMode.inputDigit
    ) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextField(
          controller: _inputController,
          textAlign: card.style.answerVariantAlign,
          keyboardType: answerInputMode == AnswerInputMode.inputDigit? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blue),
              borderRadius: BorderRadius.circular(15),
            ),
            suffixIcon : IconButton(
              icon: const Icon(Icons.check, color: Colors.lightGreen),
              onPressed: ()=> _onSelectAnswer(_inputController.text),
            ),
          ),
        ),
      );
    }

    // Выпадающий список
    if (answerInputMode == AnswerInputMode.ddList) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextField(
          controller: _inputController,
          readOnly: true,
          textAlign: card.style.answerVariantAlign,
          decoration: InputDecoration(
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blue),
              borderRadius: BorderRadius.circular(15),
            ),
            suffixIcon : Row( mainAxisSize: MainAxisSize.min, children: [
              popupMenu(
                  icon: const Icon(Icons.arrow_drop_down_outlined),
                  menuItemList: _answerVariantList.map<SimpleMenuItem>((value) => SimpleMenuItem(
                      child: ValueWidget(card, value),
                      onPress: () {
                        setState(() {
                          _inputController.text = value;
                        });
                      }
                  )).toList()
              ),

              IconButton(
                icon: const Icon(Icons.check, color: Colors.lightGreen),
                onPressed: ()=> _onSelectAnswer(_inputController.text),
              )
            ]),
          ),
        ),
      );
    }

    // Кнопки в строку
    if (answerInputMode == AnswerInputMode.hList) {
      return Align( child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: _answerVariantList.map<Widget>((itemStr) {
          return _getButton(itemStr, alignment);
        }).toList(),
      ));
    }

    // Кнопки в столбец
    if (answerInputMode == AnswerInputMode.vList) {
      return ListView(
        shrinkWrap: true,
        children: _answerVariantList.map<Widget>((itemStr) {
          return _getButton(itemStr, alignment);
        }).toList(),
      );
    }

    // Виртуальная клавиатура
    if (answerInputMode == AnswerInputMode.widgetKeyboard) {
      final keyStr = card.style.widgetKeyboard!;
//      const keyStr = '1\t2\t3\n4\t5\t6\n7\t8\t9\n0';
      return _WidgetKeyboard(card, keyStr, onAnswer: (value)=> _onSelectAnswer(value));
    }

    return Container();
  }

  Widget _getButton(String value, AlignmentGeometry alignment){
    if (card.style.answerVariantMultiSel) {
      if ( _answerValues.contains(value) ) {

        return ElevatedButton(
          style: ElevatedButton.styleFrom(alignment: alignment, backgroundColor: Colors.amberAccent),
          child: ValueWidget(card, value),
          onPressed: () {
            setState(() {
              _answerValues.remove(value);
            });
          },
        );

      } else {

        return ElevatedButton(
          style: ButtonStyle(alignment: alignment),
          child: ValueWidget(card, value),
          onPressed: () {
            setState(() {
              _answerValues.add(value);
            });
          },
        );

      }
    }

    return ElevatedButton(
      style: ButtonStyle(alignment: alignment),
      child: ValueWidget(card, value),
      onPressed: () => _onSelectAnswer(value),
    );
  }

  void _onSelectAnswer(String answerValue,[List<String>? answerList]) {
    _answerValues.clear();
    _answerValues.add(answerValue);

    bool tryResult = false;

    if (card.style.answerCaseSensitive) {
      tryResult = card.body.answerList.any((str) => str == answerValue);
    } else {
      answerValue = answerValue.toLowerCase();
      tryResult = card.body.answerList.any((str) => str.toLowerCase() == answerValue);
    }

    if (!tryResult && answerList != null) {
      if (card.style.answerCaseSensitive) {
        tryResult = answerList.any((str) => str == answerValue);
      } else {
        answerValue = answerValue.toLowerCase();
        tryResult = answerList.any((str) => str.toLowerCase() == answerValue);
      }
    }

    onAnswer(tryResult);
  }

  void _onMultiSelectAnswer() {
    List<String> answerList;

    if (card.style.answerCaseSensitive) {
      answerList = card.body.answerList;
    } else {
      answerList = card.body.answerList.map((str) => str.toLowerCase()).toList();
    }

    int answerCount = 0;
    for (var value in _answerValues) {
      if (!card.style.answerCaseSensitive) {
        value = value.toLowerCase();
      }

      if (!answerList.contains(value)) {
        onAnswer(false);
        return;
      }
      answerCount ++;
    }

    if (card.body.answerList.length != answerCount) {
      onAnswer(false);
      return;
    }

    onAnswer(true);
  }

  void onAnswer(bool tryResult) {
    if (tryResult) {
      widget.controller.setResult(tryResult, _tryCount);
      return;
    }

    _tryCount ++;

    if (_tryCount < cardParam.tryCount) {
      Fluttertoast.showToast(msg: TextConst.txtWrongAnswer);
      return;
    }

    widget.controller.setResult(false, _tryCount);
  }
}

typedef OnKeyboardAnswer = Function(String value);

class _WidgetKeyboard extends StatefulWidget {
  final CardData card;
  final String keyStr;
  final OnKeyboardAnswer onAnswer;
  const _WidgetKeyboard(this.card, this.keyStr, {required this.onAnswer, Key? key}) : super(key: key);

  @override
  State<_WidgetKeyboard> createState() => _WidgetKeyboardState();
}

class _WidgetKeyboardState extends State<_WidgetKeyboard> {
  String _widgetKeyboardText = '';

  @override
  Widget build(BuildContext context) {
    final keyBoard = widget.keyStr.split('\n').map((row) {
      return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.split('\t').map((key) => Padding(
            padding: const EdgeInsets.only(left: 5, right: 5),
            child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _widgetKeyboardText += key;
                  });
                },
                child: ValueWidget(widget.card, key.trim()) ),
          )
          ).toList());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Container(
              decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue,
                    width: 2,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(10))
              ),

              child:  Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.black),
                    onPressed: (){
                      setState(() {
                        _widgetKeyboardText = "";
                      });
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, color: Colors.black),
                    onPressed: (){
                      if (_widgetKeyboardText.isEmpty) return;
                      setState(() {
                        _widgetKeyboardText = _widgetKeyboardText.substring(0, _widgetKeyboardText.length - 1);
                      });
                    },
                  ),

                  Expanded(
                    child: Container(
                      color: Colors.black12,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, right: 4),
                        child: AutoSizeText(
                          _widgetKeyboardText,
                          style: TextStyle(fontSize: context.textTheme.headlineMedium!.fontSize, color: Colors.blue),
//                  textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.lightGreen),
                    onPressed: ()=> widget.onAnswer.call(_widgetKeyboardText),
                  )
                ],
              )
          ),
        ),

        ListView(
          shrinkWrap: true,
          children: keyBoard,

        ),
      ],
    );
  }
}

class RightAnswerLine extends StatelessWidget {
  final CardData card;
  final String label;
  const RightAnswerLine({required this.card, required this.label, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final answerList = <Widget>[];
    answerList.add(Text('$label '));

    for (int i = 0; i < card.body.answerList.length; i++){
      final answerValue = card.body.answerList[i];
      answerList.add(ValueWidget(card, answerValue));

      if ((card.body.answerList.length > 1) && ((i + 1) < card.body.answerList.length)){
        answerList.add(const Text("; "));
      }
    }

    return Row(children: answerList);
  }
}

class HelpButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int delayDuration;
  final VoidCallback onTap;

  const HelpButton({
    required this.icon,
    required this.color,
    required this.delayDuration,
    required this.onTap,
    Key? key}) : super(key: key);

  @override
  State<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<HelpButton> {
  bool _active = false;

  @override
  void initState() {
    super.initState();

    if (widget.delayDuration == 0) {
      _active = true;
    } else {
      Future.delayed(Duration(seconds: widget.delayDuration), (){
        if (!mounted) return;

        setState(() {
          _active = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_active) {
      return InkWell(
        onTap: widget.onTap,
        child: Icon(widget.icon, color: widget.color)
      );
    }

    return InkWell(
      child: Icon(widget.icon, color: Colors.grey)
    );
  }
}
