import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import '../media_widgets.dart';
import 'word_grid.dart';
import 'word_panel.dart';
import 'word_panel_model.dart';
import 'package:flutter/material.dart';

import 'package:simple_events/simple_events.dart';

import '../common.dart';
import 'drag_box_widget.dart';

typedef RegisterAnswer = void Function(String answerValue, List<String>? answerList);
typedef PrepareFilePath = String? Function(String fileName);
typedef Decorator = Widget Function(Widget child);

class TextConstructorWidget extends StatefulWidget {
  final TextConstructorData textConstructor;
  final RegisterAnswer? onRegisterAnswer;
  final PrepareFilePath? onPrepareFileUrl;
  final int? randomPercent;
  final bool viewOnly; // no edit panel + no basement + no empty space row at bottom + no moving + no menu
  final bool noBasement;
  final void Function(int pos, String label)? onTapLabel;
  final GridDragBoxTap? onBasementTap;
  final List<Widget>? toolbarLeading;
  final List<Widget>? toolbarTrailing;
  final Decorator? toolbarDecorator;
  final Decorator? wordPanelDecorator;
  final Decorator? basementPanelDecorator;
  final void Function(double)? onChangeHeight;
  final VoidCallback? onChangeBasement;

  const TextConstructorWidget({
    required this.textConstructor,
    this.onRegisterAnswer,
    this.onPrepareFileUrl,
    this.randomPercent,
    this.viewOnly = false,
    this.noBasement = false,
    this.onTapLabel,
    this.onBasementTap,
    this.toolbarLeading,
    this.toolbarTrailing,
    this.toolbarDecorator,
    this.wordPanelDecorator,
    this.basementPanelDecorator,
    this.onChangeHeight,
    this.onChangeBasement,

    Key? key
  }) : super(key: key);

  @override
  State<TextConstructorWidget> createState() => TextConstructorWidgetState();
}

class _HistData {
  String panelStr;
  String basementStr;
  _HistData(this.panelStr, this.basementStr);
}

class _RandomDelWordResult {
  final String text;
  final String delWords;
  _RandomDelWordResult(this.text, this.delWords);
}

class TextConstructorWidgetState extends State<TextConstructorWidget> with AutomaticKeepAliveClientMixin<TextConstructorWidget> {
  late TextConstructorData textConstructorData;
  late WordPanelController panelController;
  late WordGridController?  basementController;

  final Color  _defaultTextColor  = Colors.white;
  final Color  _borderColor      = Colors.black;
  final double _borderWidth      = 1.0;
  final Color  _tapInProcessBorderColor  = Colors.green;
  final Color  _focusBorderColor  = Colors.blue;
  final double _focusBorderWidth  = 2.0;
  final Color  _editPosColor      = Colors.blue;
  final Color  _insertPosColor    = Colors.green;
  final Color  _colorWordNormal   = Colors.grey;
  final Color  _colorWordCanDrop  = Colors.amber;
  final Color  _colorWordMove     = Colors.black12;
  final double _editPosWidth      = 10;
  final double _insertPosWidth    = 10;

  final _historyList = <_HistData>[];
  bool _historyRecordOn = true;
  int _historyPos = -1;

  final _toolBarRefresh = SimpleEvent();

  bool   _starting = true;
  double _panelHeight = 0.0;
  double _basementHeight = 0.0;

  final _panelKey = GlobalKey();
  final _basementKey = GlobalKey();

  late Decorator _toolbarDecorator;
  late Decorator _wordPanelDecorator;
  late Decorator _basementPanelDecorator;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    textConstructorData = widget.textConstructor; //TextConstructorData.fromMap(jsonDecode(textConstructorJson));

    var panelText = textConstructorData.text;
    var basementText = widget.textConstructor.basement;

    if (widget.randomPercent != null) {
      if (textConstructorData.randomMixWord) {
        panelText = _randomMixWord(panelText, widget.randomPercent!);
      }
      if (textConstructorData.randomDelWord) {
        final delResult = _randomDelWord(panelText, widget.randomPercent!);
        panelText = delResult.text;
        basementText = '$basementText ${delResult.delWords}';
      }
    }

    _toolbarDecorator       = widget.toolbarDecorator       ?? _toolbarDefaultDecorator;
    _wordPanelDecorator     = widget.wordPanelDecorator     ?? _wordPanelDefaultDecorator;
    _basementPanelDecorator = widget.basementPanelDecorator ?? _basementPanelDefaultDecorator;

    panelController = WordPanelController(
      text          : panelText,
      onChange      : _onChange,
      canMoveWord   : textConstructorData.canMoveWord && !widget.viewOnly,
      noCursor      : textConstructorData.noCursor,
      focusAsCursor : textConstructorData.focusAsCursor,
    );

    if (!widget.noBasement && !widget.viewOnly) {
      basementController = WordGridController(basementText);
    } else {
      basementController = null;
    }

  }

  @override
  void didUpdateWidget(covariant TextConstructorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.viewOnly != oldWidget.viewOnly) {
      panelController.canMoveWord = textConstructorData.canMoveWord && !widget.viewOnly;
      if (widget.viewOnly) {
        _panelHeight -= panelController.wordBoxHeight;
      } else {
        _panelHeight += panelController.wordBoxHeight;
      }
    }

  }

  String _randomMixWord(String text, int percent) {
    final wordList = WordPanelController.textToWordList(text);
    final count = ( wordList.length * percent ) ~/ 100;
    final wordListLength = wordList.length;

    final random = Random();

    for ( var i = 0; i < count ; i++) {
      final delPos = random.nextInt(wordListLength);
      final word = wordList[delPos];
      wordList.removeAt(delPos);

      final insPos = random.nextInt(wordListLength);
      wordList.insert(insPos, word);
    }

    final result = WordPanelController.wordListToText(wordList);
    return result;
  }

  _RandomDelWordResult _randomDelWord(String text, int percent) {
    final wordList = WordPanelController.textToWordList(text);
    final count = ( wordList.length * percent ) ~/ 100;
    final wordListLength = wordList.length;
    final delWords = <String>[];

    final random = Random();

    for ( var i = 0; i < count ; i++) {
      final delPos = random.nextInt(wordListLength);
      final word = wordList[delPos];
      wordList.removeAt(delPos);
      delWords.add(word);
    }

    final newText = WordPanelController.wordListToText(wordList);
    final delWordsText = WordPanelController.wordListToText(delWords);

    return _RandomDelWordResult(newText, delWordsText);
  }

  void _onChange() {
    if (_starting) return;
    if (!_historyRecordOn) return;

    if (_historyPos >= 0) {
      _historyList.removeRange(_historyPos + 1, _historyList.length);
      _historyPos = -1;
    }

    final panelStr = panelController.text;
    if (_historyList.isNotEmpty && _historyList.last.panelStr == panelStr) {
      return;
    }

    final basementStr = basementController?.getVisibleWords()??'';

    _historyList.add(_HistData(panelStr, basementStr));
    _toolBarRefresh.send();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      WidgetsBinding.instance.addPostFrameCallback((_){
        if (!mounted) return;
        if (_starting) {
          setState(() {
            _starting = false;
            _onChange();
          });
        }
      });

      if (_starting) {
        return Offstage(
          child: _startBody(),
        );
      }

      return _body(viewportConstraints);
    });

  }

  Widget _body(BoxConstraints viewportConstraints) {
    if (widget.viewOnly) {
      return _wordPanelDecorator(
        SizedBox(
          height: _panelHeight,
          child: _wordPanel()
        )
      );
    }

    if (widget.noBasement) {
      return Column(
        children: [

          _toolbarDecorator(
              _toolbar()
          ),

          _wordPanelDecorator(
              SizedBox(
                  height: _panelHeight,
                  child: _wordPanel()
              )
          ),
        ],
      );
    }

    if (_basementHeight == 0.0) {
      return Column(
        children: [

          _toolbarDecorator(
            _toolbar()
          ),

          _wordPanelDecorator(
            SizedBox(
              height: _panelHeight,
              child: _wordPanel()
            )
          ),

          Offstage( child: SizedBox(
            height:  300,
            child: _basement(),
          )),
        ],
      );
    }

    return Column(
      children: [

        _toolbarDecorator(
          _toolbar()
        ),

        _wordPanelDecorator(
          SizedBox(
              height: _panelHeight,
              child: _wordPanel()
          )
        ),

        _basementPanelDecorator(
          SizedBox(
            height:  _basementHeight,
            child: _basement(),
          )
        ),
      ],
    );

  }

  Widget _startBody() {
    return Column(
      children: [

        SizedBox(
          height: 100,
          child: _wordPanel(),
        ),

        if (!widget.noBasement && !widget.viewOnly) ...[
          SizedBox(
              height: 100,
              child: _basement()
          ),
        ],

      ],
    );
  }

  Widget _wordPanel() {
    return WordPanel(
      key                : _panelKey,
      controller         : panelController,
      onDragBoxBuild     : _onDragBoxBuild,
      onDragBoxTap       : _onDragBoxTap,
      onDragBoxLongPress : _onDragBoxLongPress,
      onDoubleTap        : _onDragBoxLongPress,
      onChangeHeight     : (double newHeight) {
        final extHeight = newHeight + (widget.viewOnly? 0 : panelController.wordBoxHeight);
        if (_panelHeight != extHeight) {
          setState(() {
            _panelHeight = extHeight;
          });
        }
      },
    );
  }

  Widget _basement() {
    return WordGrid(
      key            : _basementKey,
      controller     : basementController!,
      onDragBoxBuild : _onBasementBoxBuild,
      onDragBoxTap   : widget.onBasementTap??_onBasementBoxTap,
      onDragBoxLongPress: _onBasementBoxLongPress,
      onChangeBasement: widget.onChangeBasement,
      onChangeHeight : (double newHeight) {
        final extHeight = newHeight;
        if (_basementHeight != extHeight) {
          setState(() {
            _basementHeight = extHeight;
          });
        }
        widget.onChangeHeight?.call(newHeight);
      },
    );
  }

  Widget _toolbar() {
    return  EventReceiverWidget(
        events: [_toolBarRefresh],
        builder: (BuildContext context) {
          return BottomAppBar(
              color: Colors.blue,
              child: IconTheme(
                data: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [

                  if (widget.toolbarLeading != null) ...[
                    ...widget.toolbarLeading!,
                  ],

                  if (textConstructorData.btnKeyboard) ...[
                    IconButton(
                      onPressed: () async {
                        final word = await _wordInputDialog(context);
                        if (word.isEmpty) return;

                        final pos = panelController.getCursorPos(lastPostIfNot: true);
                        panelController.saveCursor();
                        panelController.insertWord(pos, word);
                        panelController.refreshPanel();
                      },
                      icon: const Icon(Icons.keyboard_alt_outlined),
                    ),
                  ],

                  if (textConstructorData.btnUndo) ...[
                    IconButton(
                      onPressed: (_historyPos == 0 || _historyList.length == 1) ? null : (){
                        if (_historyPos < 0) {
                          _historyPos = _historyList.length - 2;
                        } else {
                          _historyPos --;
                        }

                        _historyRecordOn = false;
                        final histData = _historyList[_historyPos];
                        panelController.text = histData.panelStr;
                        basementController?.setVisibleWords(histData.basementStr);
                        _historyRecordOn = true;

                        _toolBarRefresh.send();
                      },
                      icon: const Icon(Icons.undo_outlined),
                    ),
                  ],

                  if (textConstructorData.btnRedo) ...[
                    IconButton(
                      onPressed: (_historyPos < 0 || _historyPos == (_historyList.length - 1) ) ? null : (){
                        _historyPos ++;
                        _historyRecordOn = false;
                        final histData = _historyList[_historyPos];
                        panelController.text = histData.panelStr;
                        basementController?.setVisibleWords(histData.basementStr);
                        _historyRecordOn = true;

                        _toolBarRefresh.send();
                      },
                      icon: const Icon(Icons.redo_outlined),
                    ),
                  ],

                  if (textConstructorData.btnBackspace) ...[
                    IconButton(
                      onPressed: ()=> _deleteWord(-1),
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ],

                  if (textConstructorData.btnDelete) ...[
                    IconButton(
                      onPressed: ()=> _deleteWord(),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],

                  if (textConstructorData.btnClear) ...[
                    IconButton(
                      onPressed: (){
                        panelController.text = '';
                      },
                      icon: const Icon(Icons.clear_outlined),
                    ),
                  ],

                  if (widget.onRegisterAnswer != null) ...[
                    IconButton(
                      onPressed: (){
                        widget.onRegisterAnswer!.call(panelController.text, textConstructorData.answerList);
                      },
                      icon: const Icon(Icons.check, color: Colors.lightGreenAccent),
                    ),
                  ],

                  if (widget.toolbarTrailing != null) ...[
                    ...widget.toolbarTrailing!,
                  ]

                ]),
              )
          );
        }
    );
  }

  void _deleteWord([int posAdd = 0]){
    var pos = panelController.getCursorPos(onlyCursor: true);

    bool cursor = false;
    if (pos < 0) {
      pos = panelController.getFocusPos();
      if (pos < 0) return;
    } else {
      cursor = true;
    }

    pos += posAdd;

    if (pos < 0) return;

    if (cursor) {
      if (pos == 0) {
        panelController.saveCursor(pos + 1);
      } else {
        panelController.saveCursor(pos);
      }
    }

    var word = panelController.getWord(pos);

    final wordInfo = LabelInfo(word);

    if (wordInfo.isObject) {
      final wordObject = getWordObject(wordInfo.objectName);
      if (wordObject.nonRemovable) return;
    }

    basementController?.addWord(wordInfo.word);

    panelController.deleteWord(pos);
    panelController.refreshPanel();
  }

  Future<String?> _onDragBoxTap(String label, Widget child, int pos, Offset position, Offset globalPosition) async {
    if (label.isEmpty) return label;

    widget.onTapLabel?.call(pos, label);

    final labelInfo = LabelInfo(label);
    String text;
    if (labelInfo.isObject) {
      final wordObject = textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == labelInfo.objectName);
      if (wordObject == null) return null;
      final viewInfo = wordObject.views[labelInfo.viewIndex];
      text = viewInfo.text;
    } else {
      text = labelInfo.word;
    }

    final textInfo = TextInfo(text);

    if (textInfo.audio.isNotEmpty) {
      final filePath = widget.onPrepareFileUrl!(textInfo.audio);
      if (filePath != null) {
        await playAudioUrl(filePath);
      }
    }

    if (textInfo.text == JrfSpecText.wordKeyboard) {
      if (!mounted) return null;
      final inputValue = await _wordInputDialog(context);
      if (inputValue.isEmpty) return null;
      return inputValue;
    }

    if (textConstructorData.markStyle >= 0) {
      if (label.startsWith(LabelInfo.selectPrefix)) {
        label = label.substring(1);
      } else {
        label = '${LabelInfo.selectPrefix}$label';
      }
    }

    return label;
  }

  Future<String?> _onDragBoxLongPress(String label, Widget child, int pos, Offset position, Offset globalPosition) async {
    return _showPopupMenu(label, globalPosition);
  }

  Widget _editPosWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        color: _editPosColor,
      ),
      width: _editPosWidth,
      height: panelController.wordBoxHeight,
    );
  }

  Widget _insertPosWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        color: _insertPosColor,
      ),
      width: _insertPosWidth,
      height: panelController.wordBoxHeight,
    );
  }

  Widget _onDragBoxBuild(BuildContext context, PanelBoxExt ext){ //String label, DragBoxSpec spec) {
    if (ext.spec == DragBoxSpec.editPos){
      return _editPosWidget();
    }

    if (ext.spec == DragBoxSpec.insertPos){
      return _insertPosWidget();
    }

    return labelWidget(context, ext.label, ext.spec);
  }

  Widget _basementGroupHead(BuildContext context, String label) {
    return Text(label);
  }

  Widget _onBasementBoxBuild(BuildContext context, GridBoxExt ext) {
    if (ext.isGroup) {
      return _basementGroupHead(context, ext.label);
    }

    return labelWidget(context, ext.label, ext.spec);
  }

  double _internalBoxHeight() {
    if (textConstructorData.boxHeight > 0) {
      return textConstructorData.boxHeight - 2;
    }

    if (panelController.wordBoxHeight == 0.0) return 20.0;
    return panelController.wordBoxHeight - 2;
  }

  WordObject getWordObject(String objectName) {
    final wordObject = textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;
    return wordObject;
  }

  Widget labelWidget(BuildContext context, String label, DragBoxSpec spec) {
    if (label.isEmpty) return Container();

    int? styleIndex;

    final labelInfo = LabelInfo(label);

    if (labelInfo.isSelected && textConstructorData.markStyle >= 0) {
      styleIndex = textConstructorData.markStyle;
    }

    if (labelInfo.isObject) {
      final wordObject = textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == labelInfo.objectName);
      if (wordObject == null) return Container(); // its possible when object was removed in editor

      final viewInfo = wordObject.views[labelInfo.viewIndex];

      return getObjectViewWidget(context, objectName: labelInfo.objectName, viewInfo: viewInfo, styleIndex: styleIndex, spec: spec );
    }

    if (labelInfo.isSelected) {
      label = LabelInfo.unSelect(label);
    }

    return getObjectViewWidget(context, label: label, styleIndex: styleIndex, spec : spec );
  }

  Widget getObjectViewWidget(BuildContext context, {
    String      label      = '',
    String      objectName = '',
    ViewInfo?   viewInfo,
    int?        styleIndex,
    DragBoxSpec spec       = DragBoxSpec.none,
    bool        forPopup   = false
  }) {
    var textStyleBold   = false;
    var textStyleItalic = false;

    var textColor       = _defaultTextColor;
    var backgroundColor = _colorWordNormal;

    var lineColor = Colors.black;
    var linePos   = TextDecoration.none;
    var lineStyle = TextDecorationStyle.solid;

    var borderColor = _borderColor;
    var borderWidth = _borderWidth;

    var menuText = '';

    var outText = '';

    var localStyleIndex = -1;

    if (viewInfo != null) {
      outText         = viewInfo.text;
      localStyleIndex = viewInfo.styleIndex;
      menuText        = viewInfo.menuText;
    }

    if (outText.isEmpty && objectName.isNotEmpty) {
      outText = objectName;
    }

    if (label.isNotEmpty) {
      outText = label;
    }

    if (styleIndex != null) {
      localStyleIndex = styleIndex;
    }

    if (localStyleIndex >= 0) {
      final styleInfo = textConstructorData.styles[localStyleIndex];
      textStyleBold = styleInfo.fontBold;
      textStyleItalic = styleInfo.fontItalic;

      if (styleInfo.charColor != null) {
        textColor = styleInfo.charColor!;
      }
      if (styleInfo.backgroundColor != null) {
        backgroundColor = styleInfo.backgroundColor!;
      }
      if (styleInfo.frameColor != null) {
        borderColor = styleInfo.frameColor!;
      }

      if (styleInfo.linePos != null) {
        linePos   = styleInfo.linePos!;
        lineStyle = styleInfo.lineStyle!;
        lineColor = styleInfo.lineColor!;
      }
    }

    if (spec == DragBoxSpec.move) {
      backgroundColor = _colorWordMove;
    }
    if (spec == DragBoxSpec.canDrop) {
      backgroundColor = _colorWordCanDrop;
    }
    if (spec == DragBoxSpec.tapInProcess) {
      borderColor = _tapInProcessBorderColor;
      borderWidth = _focusBorderWidth;
    }
    if (spec == DragBoxSpec.focus) {
      borderColor = _focusBorderColor;
      borderWidth = _focusBorderWidth;
    }

    var textInfo = TextInfo(outText);

    if (forPopup && menuText.isNotEmpty && menuText != textInfo.text) {
      textInfo = TextInfo(menuText);
    }

    Widget? retWidget;
    bool setHeight = true;

    if (retWidget == null && textInfo.image.isNotEmpty) {
      final fileUrl = widget.onPrepareFileUrl!.call(textInfo.image);
      if (fileUrl != null) {
        retWidget = imageFromUrl(fileUrl);
        if (retWidget is Image && forPopup) {
          setHeight = false;
          final screenSize =  MediaQuery.of(context).size;
          retWidget = LimitedBox(
            maxHeight: screenSize.height / 3,
            maxWidth: screenSize.width - 100,
            child: retWidget,
          );
        }
      }
    }

    if (retWidget == null && textInfo.audio.isNotEmpty && textInfo.text.isEmpty) {
      final fileUrl = widget.onPrepareFileUrl!.call(textInfo.audio);
      if (fileUrl != null) {
        retWidget = audioButtonFromUrl(fileUrl, textColor);
      }
    }

    if (retWidget == null && textInfo.text == JrfSpecText.wordKeyboard) {
      retWidget = Icon(Icons.keyboard_alt_outlined, color: textColor);
    }

    if (retWidget != null && setHeight) {
      retWidget = SizedBox(
          height : _internalBoxHeight(),
          child  : retWidget
      );
    }

    retWidget ??= Container(
        color: backgroundColor,
        child: Text(
          textInfo.text,
          style: TextStyle(
            color: textColor,

            decoration     : linePos,
            decorationColor: lineColor,
            decorationStyle: lineStyle,

            fontSize: textConstructorData.fontSize,
            fontWeight: textStyleBold? FontWeight.bold : null,
            fontStyle: textStyleItalic? FontStyle.italic : null,
          ),
        ),
    );

    if (forPopup) {
      return _BoxWidget(
        outStr: textInfo.text,
        menuText: menuText,
        child: _makeDecoration(
          child           : retWidget,
          borderColor     : _borderColor,
          borderWidth     : _borderWidth,
          backgroundColor : backgroundColor,
        ),
      );
    }

    return _BoxWidget(
      outStr: textInfo.text,
      menuText: menuText,
      child: _makeDecoration(
        child           : retWidget,
        borderColor     : borderColor,
        borderWidth     : borderWidth,
        backgroundColor : backgroundColor,
      ),
    );
  }

  Widget _makeDecoration({
    required Widget child,
    required Color  borderColor,
    required double borderWidth,
    required Color  backgroundColor,
  }){
    double hPadding = 10;
    double cRadius = 8;

    //hPadding = 0; // это для обрезки картики без отступов
    if (hPadding == 0) {
      cRadius = 20;
    }

    double addPadding = 0;

    if (borderWidth < 2) {
      addPadding = 2 - borderWidth;
    }

    return  Container(
      height: textConstructorData.boxHeight > 0 ? textConstructorData.boxHeight : null,
      padding: EdgeInsets.only(left: hPadding + addPadding, right: hPadding + addPadding, top: addPadding, bottom: addPadding),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        color: backgroundColor,
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(cRadius)),
          child: child
      ),
    );
  }

  Future<String?> _showPopupMenu(String label, Offset position) async {
    if (widget.viewOnly) return null;
    if (label.isEmpty) return null;
    final labelInfo = LabelInfo(label);

    if (!labelInfo.isObject) return null;

    final wordObject = textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == labelInfo.objectName)!;

    final popupItems = <PopupMenuEntry<String>>[];

    for ( var i = 0; i < wordObject.views.length; i++ ) {
      final viewInfo = wordObject.views[i];
      final popupItemWidget = getObjectViewWidget(context, objectName: labelInfo.objectName, viewInfo: viewInfo, forPopup: true) as _BoxWidget;
      if (popupItemWidget.menuText == JrfSpecText.hideMenuItem) continue;

      popupItems.add( PopupMenuItem(
          value: '#$i|${labelInfo.objectName}',
          padding: EdgeInsets.zero,
          child: Center(child: Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 1),
            child: popupItemWidget,
          ))
      ));
    }

    if (popupItems.length < 2) {
      return null;
    }

    final value = await showMenu<String>(
      context  : context,
      position : RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items    : popupItems,
      shape: const RoundedRectangleBorder( borderRadius: BorderRadius.all(Radius.circular(5)) ),
    );

    return value;
  }

  void _onBasementBoxTap(DragBoxInfo<GridBoxExt> boxInfo, int boxInfoIndex, Offset position, Offset globalPosition) {
    if (!textConstructorData.notDelFromBasement){
      boxInfo.setState(visible: false);
      basementController?.refresh();
    }

    final curPos = panelController.getCursorPos(lastPostIfNot: true);
    panelController.saveCursor();
    panelController.insertWord(curPos, boxInfo.data.ext.label);
    panelController.refreshPanel();
  }

  _onBasementBoxLongPress(DragBoxInfo<GridBoxExt> boxInfo, int boxInfoIndex, Offset position, Offset globalPosition) async {
    final newLabel = await _showPopupMenu(boxInfo.data.ext.label, globalPosition);
    if (newLabel == null || newLabel.isEmpty) return;
    basementController!.setLabel(boxInfoIndex, newLabel);
  }

  Future<String> _wordInputDialog(BuildContext context) async {
    final textController = TextEditingController();
    String  word = '';

    final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(TextConst.txtDialogInputText),
            content: TextField(
              onChanged: (value) {
                word = value;
              },
              controller: textController,
            ),
            actions: <Widget>[
              IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
                word = '';
                Navigator.pop(context, false);
              }),

              IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: () {
                Navigator.pop(context, true);
              }),

            ],
          );
        });

    //textController.dispose();

    if (result != null && result) return word;

    return '';
  }

  Widget _toolbarDefaultDecorator(Widget child) {
    return child;
  }
  Widget _wordPanelDefaultDecorator(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: child,
    );
  }
  Widget _basementPanelDefaultDecorator(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          const Divider(
            color: Colors.black,
          ),
          child,
        ],
      ),
    );
  }

  void refresh() {
    panelController.refreshPanel();
    basementController?.refresh();
    setState(() {});
  }
}

class _BoxWidget extends StatelessWidget {
  final Widget child;
  final String outStr;
  final String menuText;

  const _BoxWidget({required this.child, required this.outStr, required this.menuText, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

