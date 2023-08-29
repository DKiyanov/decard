import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:decard/text_constructor/text_constructor.dart';
import 'package:decard/text_constructor/word_panel.dart';
import 'package:decard/text_constructor/word_panel_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart' as path_util;

import 'audio_button.dart';
import 'audio_widget.dart';
import 'card_model.dart';
import 'common.dart';
import 'decardj.dart';
import 'html_widget.dart';

final _random = Random();

class CardWidget extends StatefulWidget {
  final CardData card;
  final VoidCallback? onPressSelectNextCard;
  final bool demoMode;

  const CardWidget({required this.card, this.onPressSelectNextCard, this.demoMode = false,  Key? key}) : super(key: key);

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget> {
  int       _cardHashCode = 0;

  int       _tryCount = 0;
  bool?     _result;

  final     _answerVariantList = <String>[]; // список вариантов ответов
  final     _selValues = <String>[]; // Выбранные значения

  int       _costDuration = 0; // длительность в мимлисекундах
  double    _costValue = 0; // заработанное
  double    _timeProgress = 0; // процент потраченого времени
  Timer?    _costTimer;
  DateTime? _startTime;
  final     _inputController = TextEditingController(); // Для полей ввода
  String    _widgetKeyboardText = '';

  void _prepareAnswerVariantList() {
    // списку из body отдаётся предпочтение
    _answerVariantList.clear();
    _answerVariantList.addAll(widget.card.style.answerVariantList);

    // выдёргиваем из списка лишние варианты так чтоб полчился список нужного размера
    if (widget.card.style.answerVariantCount > widget.card.body.answerList.length && _answerVariantList.length > widget.card.style.answerVariantCount){
      while (_answerVariantList.length > widget.card.style.answerVariantCount) {
        final rndIndex = _random.nextInt(_answerVariantList.length);
        final variant = _answerVariantList[rndIndex];
        if (!widget.card.body.answerList.contains(variant)) {
          _answerVariantList.removeAt(rndIndex);
        }
      }
    }

    if (widget.card.style.answerVariantListRandomize) {
      // перемешиваем список в случайном порядке
      _answerVariantList.shuffle(_random);
    }
  }

  // Проверяет что карточка изменилась и подготавливает начальное состояние для
  // просмотра новой карточки
  // вызывается из build в самом начале
  // решает следущую проблему:
  // cardController установил карточку и вызвал notifyListeners()
  // ChangeNotifierProvider увидел изменение и вызвал перисовку ... Consumer
  // вызвался метод _CardWidgetState.build
  // внешнее состояние на данный момент изменённое,
  // а вот внутренне состояние (_CardWidgetState) ещё не знает об изменениях
  // метод _cardChangeCheckAndPrepare проверяет наличие изменения
  // и если оно есть подготавливает внутренне состояние виджета
  void _cardChangeCheckAndPrepare(){
    if (_cardHashCode == widget.card.hashCode) return;

    _cardHashCode = widget.card.hashCode;
    _clearState();
    _startDisplayCard();
  }

  void _onMultiSelectAnswer() {
    List<String> answerList;

    if (widget.card.style.answerCaseSensitive) {
      answerList = widget.card.body.answerList;
    } else {
      answerList = widget.card.body.answerList.map((str) => str.toLowerCase()).toList();
    }

    int answerCount = 0;
    for (var value in _selValues) {
      if (!widget.card.style.answerCaseSensitive) {
        value = value.toLowerCase();
      }

      if (!answerList.contains(value)) {
        _onAnswer(false);
        return;
      }
      answerCount ++;
    }

    if (widget.card.body.answerList.length != answerCount) {
      _onAnswer(false);
      return;
    }

    _onAnswer(true);
  }

  void _onSelectAnswer(String answerValue,[List<String>? answerList]) {
    _selValues.clear();
    _selValues.add(answerValue);

    bool tryResult = false;

    if (widget.card.style.answerCaseSensitive) {
      tryResult = widget.card.body.answerList.any((str) => str == answerValue);
    } else {
      answerValue = answerValue.toLowerCase();
      tryResult = widget.card.body.answerList.any((str) => str.toLowerCase() == answerValue);
    }

    if (!tryResult && answerList != null) {
      if (widget.card.style.answerCaseSensitive) {
        tryResult = answerList.any((str) => str == answerValue);
      } else {
        answerValue = answerValue.toLowerCase();
        tryResult = answerList.any((str) => str.toLowerCase() == answerValue);
      }
    }

    _onAnswer(tryResult);
  }

  void _onAnswer(bool tryResult) {
    _stopCostTimer();

    if (widget.demoMode) return;

    final solveTime = DateTime.now().difference(_startTime!).inMilliseconds;

    if (tryResult) {
      widget.card.setResult(true, _costValue, _tryCount, solveTime);

      setState(() {
        _result = true;
      });
      return;
    }

    _tryCount ++;

    if (_tryCount < widget.card.tryCount) {
      Fluttertoast.showToast(msg: TextConst.txtWrongAnswer);
      return;
    }

    widget.card.setResult(false, -widget.card.penalty.toDouble(), _tryCount, solveTime);

    setState(() {
      _result = false;
    });
  }

  void _stopCostTimer(){
    if (_costTimer != null) {
      _costTimer!.cancel();
      _costTimer = null;
    }
  }

  void _clearState() {
    _tryCount = 0;
    _result = null;
    _answerVariantList.clear();
    _selValues.clear();

    _startTime = null;
    _costValue = 0;
    _costDuration = 0;
    _timeProgress = 0;
    _inputController.text = '';
    _widgetKeyboardText = '';

    _stopCostTimer();
  }

  void _startDisplayCard() {
    if (widget.card.startTime == 0) {
      _startTime = DateTime.now();
    } else {
      _startTime = DateTime.fromMillisecondsSinceEpoch(widget.card.startTime);
    }

    _costValue = widget.card.cost.toDouble();
    _costDuration = widget.card.duration * 1000;
    _prepareAnswerVariantList();
    _initCostTimer();
  }

  void _initCostTimer() {
    _stopCostTimer();

    if (widget.demoMode) return;

    if (widget.card.duration == 0 || widget.card.cost == widget.card.lowCost) return;

    _costTimer = Timer.periodic( const Duration(milliseconds: 100), (timer){
      if (!mounted) return;

      setState(() {
        final time = DateTime.now().difference(_startTime!).inMilliseconds;

        if (time >= _costDuration) {
          _costValue = widget.card.lowCost.toDouble();
          _timeProgress = 1;
          timer.cancel();
          return;
        }

        _costValue = widget.card.cost - ( (widget.card.cost - widget.card.lowCost) * time ) / _costDuration;
        _timeProgress = time / _costDuration;
      });
    });
  }

  /// панель отображающая стоимость решения карточки, штраф за не верной решение
  /// анимация изменения стоимости от задержки при решении
  Widget _getCostPanel() {
    String panelTxt = '';

    if (_result == null) {
      panelTxt = TextConst.txtCost;
    } else {
      if (_result!){
        panelTxt = TextConst.txtEarned;
      } else {
        panelTxt = TextConst.txtPenalty;
      }
    }

    return Container(
      color: Theme.of(context).primaryColorDark,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Text(panelTxt),
            Container(width: 4),
            Expanded(child: _getCostPanelEx()),
          ],
        ),
      ),
    );
  }

  Widget _getCostPanelEx() {
    if (_result != null) {
      if (_result!) {
        return Row(children: [ _costBox(_costValue, Colors.lightGreen) ]);
      } else {
        if (widget.card.penalty != 0) {
          return Row(children: [ _costBox( - widget.card.penalty, Colors.deepOrangeAccent) ]);
        } else {
          return Row(children: [ _costBox(0, Colors.yellow) ]);
        }
      }
    }

    if (_costTimer != null) {
      return Row(children: [
        _costBox(widget.card.cost, Colors.green),
        Container(width: 4),
        Expanded(child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.green,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightGreen),
                  value: _timeProgress,
                  minHeight: 18,
                ),
              ),
              Text(_costToStr(_costValue)),
            ]
        )),
        Container(width: 4),
        _costBox(widget.card.lowCost, Colors.lightGreen),
        Container(width: 4),
        _costBox(widget.card.penalty, Colors.deepOrangeAccent),
      ]);
    }

    return Row(children: [
      _costBox(widget.card.cost, Colors.lightGreen),
      if (widget.card.penalty != 0) ...[
        Expanded(child: Container()),
        _costBox( - widget.card.penalty, Colors.deepOrangeAccent),
      ]
    ]);
  }

  Widget _costBox(cost, Color color) {
    final costStr = _costToStr(cost);

    if (costStr.length <= 2) {
      return Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: color,
          ),
          shape: BoxShape.circle,
//            borderRadius: const BorderRadius.all(Radius.circular(20))
        ),
        child: Align(child: Text(costStr)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5.0),
      decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: color,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(20))
      ),
      child: Text(costStr),
    );
  }

  String _costToStr(cost){
    if (cost is double) {
      return cost.truncate().toString();
    }

    return '$cost';
  }

  @override
  Widget build(BuildContext context) {
    _cardChangeCheckAndPrepare();

    final widgetList = <Widget>[];

    if (widget.card.body.questionData.image != null) {
      final urlType = getUrlType(widget.card.body.questionData.image!);
      final maxHeight = MediaQuery.of(context).size.height * widget.card.style.imageMaxHeight / 100;

      if ( urlType == UrlType.httpUrl ) {
        widgetList.add(
          LimitedBox(maxHeight: maxHeight, child: Image.network(widget.card.body.questionData.image!))
        );
      }

      if ( urlType == UrlType.localPath ) {
        final absPath = path_util.normalize( path_util.join(widget.card.pacInfo.path, widget.card.body.questionData.image) );
        final imgFile = File(absPath);
        if (imgFile.existsSync()) {
          widgetList.add(
              LimitedBox(maxHeight: maxHeight, child: Image.file( imgFile ))
          );
        }
      }
    }

    if (widget.card.body.questionData.audio != null) {
      final urlType = getUrlType(widget.card.body.questionData.audio!);

      if ( urlType == UrlType.httpUrl ) {
        widgetList.add(
            AudioPanelWidget(
              key:  ValueKey(widget.card.head.cardKey),
              httpUrl : widget.card.body.questionData.audio!
            )
        );
      }

      if ( urlType == UrlType.localPath ) {
        final absPath = path_util.normalize( path_util.join(widget.card.pacInfo.path, widget.card.body.questionData.audio) );
        final imgFile = File(absPath);
        if (imgFile.existsSync()) {
          widgetList.add(
              AudioPanelWidget(
                key:  ValueKey(widget.card.head.cardKey),
                localFilePath : absPath
              )
          );
        }
      }
    }

    if (widget.card.body.questionData.text != null) {
      widgetList.add(
        AutoSizeText(
          widget.card.body.questionData.text!,
          style: const TextStyle(fontSize: 30),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (widget.card.body.questionData.html != null) {
      widgetList.add(
        htmlViewer(widget.card.body.questionData.html!),
      );
    }

    if (widget.card.body.questionData.markdown != null) {
      widgetList.add(
        markdownViewer(widget.card.body.questionData.markdown!)
      );
    }

    if (widget.card.body.questionData.textConstructor != null) {
      widgetList.add(
        textConstructor(widget.card.body.questionData.textConstructor!)
      );
    }

    if (_result != null) {
      if (widget.card.style.answerInputMode == AnswerInputMode.input
      ||  widget.card.style.answerInputMode == AnswerInputMode.inputDigit
      ||  widget.card.style.answerInputMode == AnswerInputMode.widgetKeyboard
      ) {
        for (var value in _selValues) {
          widgetList.add(
              ElevatedButton(
                style: ElevatedButton.styleFrom(alignment: _getAnswerAlignment()),
                child: Text(value),
                onPressed: (){},
              )
          );
        }
      } else {
        for (var value in _answerVariantList) {
          if (_selValues.contains(value)){
            widgetList.add(
                ElevatedButton(
                  style: ElevatedButton.styleFrom(alignment: _getAnswerAlignment()),
                  child: Text(value),
                  onPressed: (){},
                )
            );
          }
        }
      }


      if (_result!){
        widgetList.add(
            Container(
                decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Colors.lightGreenAccent
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                      TextConst.txtRightAnswer,
                      textAlign: widget.card.style.answerVariantAlign
                  ),
                )
            )
        );
      } else {
        widgetList.add(
            Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  color: Colors.deepOrange
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                      TextConst.txtWrongAnswer,
                      textAlign: widget.card.style.answerVariantAlign
                  ),
                )
            )
        );

        if (!widget.card.style.dontShowAnswer) {
          widgetList.add(
              _answerLine(TextConst.txtRightAnswerIs)
          );
        }
      }
    }

    if (widget.demoMode) {
      widgetList.add(
        Container(
            decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                color: Colors.lightGreenAccent
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: _answerLine(TextConst.txtAnswerIs),
            )
        )
      );
    }

    if (_result == null && !widget.demoMode) {
      _addAnswerVariants(widgetList);
    }

    return Column(children: [
      _getCostPanel(),

      Expanded( child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child:  Stack(
          children: [
            ListView(
              children: widgetList,
            ),
            if (widget.card.style.answerVariantMultiSel && _result == null && !widget.demoMode) ...[
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: _onMultiSelectAnswer,
                  style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(17),
                      backgroundColor: Colors.green
                  ),
                  child: const Icon(Icons.check, color: Colors.white),
                )
              )
            ]
          ],
        )
      )),

      if (_result != null) ...[
        Row(
          children: [
            Expanded(child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(onPressed: widget.onPressSelectNextCard, child: Text(TextConst.txtSetNextCard)),
            )),
          ],
        ),
      ]

    ]);
  }

  Widget _answerLine(String label){
    final answerList = <Widget>[];
    answerList.add(Text('$label '));

    for (int i = 0; i < widget.card.body.answerList.length; i++){
      final answerValue = widget.card.body.answerList[i];
      answerList.add(_valueWidget(answerValue));

      if ((widget.card.body.answerList.length > 1) && ((i + 1) < widget.card.body.answerList.length)){
        answerList.add(const Text("; "));
      }
    }

    return Row(children: answerList);
  }

  Alignment _getAnswerAlignment() {
    var alignment = Alignment.center;

    switch(widget.card.style.answerVariantAlign) {
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

  void _addAnswerVariants(List<Widget> widgetList) {
    if (widget.card.body.questionData.textConstructor != null) {
      return;
    }

    Widget? answerInput;

    final alignment = _getAnswerAlignment();

    final answerInputMode = widget.card.style.answerInputMode;
//    const answerInputMode = AnswerInputMode.widgetKeyboard; // for debug

    // Поле ввода
    if ( answerInputMode == AnswerInputMode.input    ||
         answerInputMode == AnswerInputMode.inputDigit
    ) {
      var keyboardMode = TextInputType.text;

      if (answerInputMode == AnswerInputMode.inputDigit) {
        keyboardMode = TextInputType.number;
      }

      answerInput = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextField(
          controller: _inputController,
          textAlign: widget.card.style.answerVariantAlign,
          keyboardType: keyboardMode,
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
      answerInput = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextField(
          controller: _inputController,
          readOnly: true,
          textAlign: widget.card.style.answerVariantAlign,
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down_outlined),
                itemBuilder: (context) {
                  return _answerVariantList.map<PopupMenuItem<String>>((value) => PopupMenuItem<String>(
                    value: value,
                    child: _valueWidget(value),
                  )).toList();
                },
                onSelected: (value){
                  setState(() {
                    _inputController.text = value;
                  });
                },
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
      answerInput = Align( child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: _answerVariantList.map<Widget>((itemStr) {
          return _getButton(itemStr, alignment);
        }).toList(),
      ));
    }

    // Кнопки в столбец
    if (answerInputMode == AnswerInputMode.vList) {
      answerInput = ListView(
        shrinkWrap: true,
        children: _answerVariantList.map<Widget>((itemStr) {
          return _getButton(itemStr, alignment);
        }).toList(),
      );
    }

    // Виртуальная клавиатура
    if (answerInputMode == AnswerInputMode.widgetKeyboard) {
      final keyStr = widget.card.style.widgetKeyboard!;
//      const keyStr = '1\t2\t3\n4\t5\t6\n7\t8\t9\n0';
      answerInput = _widgetKeyboard(keyStr);
    }

    if (answerInput != null) widgetList.add( answerInput );
  }

  Widget _valueWidget(String str){
    if (str.isEmpty) return Container();
    if (str.indexOf(DjfCardStyle.buttonImagePrefix) == 0) {
      final imagePath = str.substring(DjfCardStyle.buttonImagePrefix.length);
      final absPath = path_util.normalize( path_util.join(widget.card.pacInfo.path, imagePath) );
      final imgFile = File(absPath);
      if (imgFile.existsSync()) {
        var maxWidth = double.infinity;
        var maxHeight = double.infinity;

        if (widget.card.style.buttonImageWidth > 0) {
          maxWidth = widget.card.style.buttonImageWidth.toDouble();
        }

        if (widget.card.style.buttonImageHeight > 0) {
          maxHeight = widget.card.style.buttonImageHeight.toDouble();
        }

        return LimitedBox(
          maxWidth  : maxWidth,
          maxHeight : maxHeight,
          child     : Image.file( imgFile )
        );
      }
    }

    // Serif - in this font, the letters "I" and "l" look different, it is important
    return Text(str, style: const TextStyle(fontFamily: 'Serif'));
  }

  Widget _getButton(String value, AlignmentGeometry alignment){
    if (widget.card.style.answerVariantMultiSel) {
      if ( _selValues.contains(value) ) {

        return ElevatedButton(
          style: ElevatedButton.styleFrom(alignment: alignment, backgroundColor: Colors.amberAccent),
          child: _valueWidget(value),
          onPressed: () {
            setState(() {
              _selValues.remove(value);
            });
          },
        );

      } else {

        return ElevatedButton(
          style: ButtonStyle(alignment: alignment),
          child: _valueWidget(value),
          onPressed: () {
            setState(() {
              _selValues.add(value);
            });
          },
        );

      }
    }

    return ElevatedButton(
      style: ButtonStyle(alignment: alignment),
      child: _valueWidget(value),
      onPressed: () => _onSelectAnswer(value),
    );
  }

  Widget _widgetKeyboard(String keyStr){
    final rowList = keyStr.split('\n');
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
                        style: const TextStyle(fontSize: 30, color: Colors.blue),
//                  textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.check, color: Colors.lightGreen),
                  onPressed: ()=> _onSelectAnswer(_widgetKeyboardText),
                )
              ],
            )
          ),
        ),

        ListView(
          shrinkWrap: true,
          children: rowList.map((row) {
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
                  child: _valueWidget(key.trim()) ),
              )
              ).toList());
          }).toList()

        ),
      ],
    );
  }

  Widget htmlViewer(String html) {
    final regexp = RegExp(r'<img[^>]*src="([^"]+)"[^>]*>', caseSensitive: false, multiLine: true);

    html = html.replaceAllMapped(regexp, (match) {
      final matchStr = match[0]!;
      final fileName = match[1];
      if (fileName == null) return matchStr;

      final str = matchStr.replaceFirst('src="$fileName', 'src="${path_util.join(widget.card.pacInfo.path, fileName)}');
      return str;
    });

    return HtmlViewWidget(html: html, filesDir: widget.card.pacInfo.path);
  }

  Widget markdownViewer(String markdown) {
    final regexp = RegExp(r'!\[.*\]\((.*?)\s*(".*")?\s*\)', caseSensitive: false, multiLine: true);

    markdown = markdown.replaceAllMapped(regexp, (match) {
      final matchStr = match[0]!;
      final fileName = match[1];
      if (fileName == null) return matchStr;

      final str = matchStr.replaceFirst(']($fileName', '](${path_util.join(widget.card.pacInfo.path, fileName)}');
      return str;
    });

    return MarkdownBody(data: markdown);
  }

  Widget textConstructor(String jsonStr) {
    final textConstructor = TextConstructorData.fromMap(jsonDecode(jsonStr));

    return TextConstructorWidget(
        textConstructor : textConstructor,
        onRegisterAnswer: _onSelectAnswer,
        onBuildViewStrWidget: textConstructorLabelWidget,
    );
  }

  Widget? textConstructorLabelWidget(BuildContext context, String viewStr, DragBoxSpec spec, Color textColor, Color backgroundColor) {
    if (viewStr.indexOf(JrfSpecText.imagePrefix) == 0) {
      final imagePath = viewStr.substring(JrfSpecText.imagePrefix.length);
      final absPath = path_util.normalize( path_util.join(widget.card.pacInfo.path, imagePath) );
      final imgFile = File(absPath);

      if (!imgFile.existsSync()) return null;

      return Image.file( imgFile );
    }

    if (viewStr.indexOf(JrfSpecText.audioPrefix) == 0) {
      final audioPath = viewStr.substring(JrfSpecText.audioPrefix.length);
      final absPath = path_util.normalize( path_util.join(widget.card.pacInfo.path, audioPath) );
      final audioFile = File(absPath);

      if (!audioFile.existsSync()) return null;

      return SimpleAudioButton(localFilePath: absPath, color: textColor);
    }

    return null;
  }
}




