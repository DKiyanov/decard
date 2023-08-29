import 'package:collection/collection.dart';
import 'package:decard/text_constructor/word_grid.dart';
import 'package:decard/text_constructor/word_panel.dart';
import 'package:decard/text_constructor/word_panel_model.dart';
import 'package:flutter/material.dart';

import 'package:simple_events/simple_events.dart';

import '../common.dart';
import 'drag_box_widget.dart';


typedef RegisterAnswer = void Function(String answerValue,[List<String>? answerList]);
typedef BuildViewStrWidget = Widget? Function(BuildContext context, String viewStr, DragBoxSpec spec, Color textColor, Color backgroundColor);

class TextConstructorWidget extends StatefulWidget {
  final TextConstructorData textConstructor;
  final RegisterAnswer onRegisterAnswer;
  final BuildViewStrWidget? onBuildViewStrWidget;
  const TextConstructorWidget({required this.textConstructor, required this.onRegisterAnswer, this.onBuildViewStrWidget, Key? key}) : super(key: key);

  @override
  State<TextConstructorWidget> createState() => _TextConstructorWidgetState();
}

class _TextConstructorWidgetState extends State<TextConstructorWidget> {
  late TextConstructorData _textConstructorData;
  late WordPanelController _panelController;
  late WordGridController  _basementController;

  final Color  _defaultTextColor  = Colors.white;
  late  double _fontSize;
  final Color  _borderColor      = Colors.black;
  final double _borderWidth      = 1.0;
  final Color  _focusBorderColor  = Colors.blue;
  final double _focusBorderWidth  = 2.0;
  final Color  _editPosColor      = Colors.blue;
  final Color  _insertPosColor    = Colors.green;
  final Color  _colorWordNormal   = Colors.grey;
//  final Color  _colorWordSelected = Colors.yellow;
  final Color  _colorWordCanDrop  = Colors.amber;
  final Color  _colorWordMove     = Colors.black12;
  final double _editPosWidth      = 10;
  final double _insertPosWidth    = 10;
//  final double _basementMinHeight = 200;

  final Map<String, Color> _colorMap = {
    'r' : Colors.red,
    'g' : Colors.green,
    'b' : Colors.blue,
    'y' : Colors.yellow,
    'o' : Colors.orange,
  };

  final _historyList = <String>[];
  bool _historyRecordOn = true;
  int _historyPos = -1;

  final _toolBarRefresh = SimpleEvent();

  bool   _starting = true;
  double _panelHeight = 0.0;
  double _basementHeight = 0.0;

  final _panelKey = GlobalKey();
  final _basementKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _textConstructorData = widget.textConstructor; //TextConstructorData.fromMap(jsonDecode(textConstructorJson));
    _fontSize = _textConstructorData.fontSize;

    _panelController = WordPanelController(
      text          : _textConstructorData.text,
      onChange      : _onChange,
      canMoveWord   : _textConstructorData.canMoveWord,
      noCursor      : _textConstructorData.noCursor,
      focusAsCursor : _textConstructorData.focusAsCursor,
    );

    _basementController = WordGridController(widget.textConstructor.basement);
  }

  void _onChange() {
    if (!_historyRecordOn) return;

    if (_historyPos >= 0) {
      _historyList.removeRange(_historyPos + 1, _historyList.length);
      _historyPos = -1;
    }

    final text = _panelController.text;
    if (_historyList.isNotEmpty && _historyList.last == text) {
      return;
    }

    _historyList.add(text);
    _toolBarRefresh.send();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      WidgetsBinding.instance.addPostFrameCallback((_){
        if (_starting) {
          setState(() {
            _starting = false;
          });
        }
      });

      if (_starting) {
        return Offstage(
          child: startBody(),
        );
      }

      return body(viewportConstraints);
    });

  }

  Widget body(BoxConstraints viewportConstraints) {
    if (_basementHeight == 0.0) {
      return Column(
        children: [

          toolbar(),

          Container(height: 4),

          SizedBox(
            height: _panelHeight,
            child: wordPanel()
          ),

          Offstage( child: SizedBox(
            height:  300,
            child: basement(),
          )),
        ],
      );
    }

    return Column(
      children: [

        toolbar(),

        Container(height: 4),

        SizedBox(
            height: _panelHeight,
            child: wordPanel()
        ),

        const Divider(
          color: Colors.black,
        ),

        SizedBox(
          height:  _basementHeight,
          child: basement(),
        ),

        Container(height: 4),
      ],
    );

  }

  Widget startBody() {
    return Column(
      children: [

        SizedBox(
          height: 100,
          child: wordPanel(),
        ),

        SizedBox(
            height: 100,
            child: basement()
        ),

      ],
    );
  }

  Widget wordPanel() {
    return WordPanel(
      key                : _panelKey,
      controller         : _panelController,
      onDragBoxBuild     : onDragBoxBuild,
      onDragBoxTap       : onDragBoxTap,
      onDragBoxLongPress : onDragBoxLongPress,
      onDoubleTap        : onDragBoxLongPress,
      onChangeHeight     : (double newHeight) {
        final extHeight = newHeight + _panelController.wordBoxHeight;
        if (_panelHeight != extHeight) {
          setState(() {
            _panelHeight = extHeight;
          });
        }
      },
    );
  }

  Widget basement() {
    return WordGrid(
      key            : _basementKey,
      controller     : _basementController,
      onDragBoxBuild : onBasementBoxBuild,
      onDragBoxTap   : onBasementBoxTap,
      onChangeHeight : (double newHeight) {
        final extHeight = newHeight;
        if (_basementHeight != extHeight) {
          setState(() {
            _basementHeight = extHeight;
          });
        }
      },
    );
  }

  Widget toolbar() {
    return  EventReceiverWidget(
        events: [_toolBarRefresh],
        builder: (BuildContext context) {
          return BottomAppBar(
              color: Colors.blue,
              child: IconTheme(
                data: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [

                  if (_textConstructorData.btnKeyboard) ...[
                    IconButton(
                      onPressed: () async {
                        final word = await wordInputDialog(context);
                        if (word.isEmpty) return;

                        final pos = _panelController.getCursorPos(lastPostIfNot: true);
                        _panelController.saveCursor();
                        _panelController.insertWord(pos, word);
                        _panelController.refreshPanel();
                      },
                      icon: const Icon(Icons.keyboard_alt_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnUndo) ...[
                    IconButton(
                      onPressed: (_historyPos == 0 || _historyList.length == 1) ? null : (){
                        if (_historyPos < 0) {
                          _historyPos = _historyList.length - 2;
                        } else {
                          _historyPos --;
                        }

                        _historyRecordOn = false;
                        _panelController.text = _historyList[_historyPos];
                        _historyRecordOn = true;

                        _toolBarRefresh.send();
                      },
                      icon: const Icon(Icons.undo_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnRedo) ...[
                    IconButton(
                      onPressed: (_historyPos < 0 || _historyPos == (_historyList.length - 1) ) ? null : (){
                        _historyPos ++;
                        _historyRecordOn = false;
                        _panelController.text = _historyList[_historyPos];
                        _historyRecordOn = true;

                        _toolBarRefresh.send();
                      },
                      icon: const Icon(Icons.redo_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnBackspace) ...[
                    IconButton(
                      onPressed: ()=> deleteWord(-1),
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ],

                  if (_textConstructorData.btnDelete) ...[
                    IconButton(
                      onPressed: ()=> deleteWord(),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],

                  if (_textConstructorData.btnClear) ...[
                    IconButton(
                      onPressed: (){
                        _panelController.text = '';
                      },
                      icon: const Icon(Icons.clear_outlined),
                    ),
                  ],

                  IconButton(
                    onPressed: (){
                      widget.onRegisterAnswer.call(_panelController.text, _textConstructorData.answerList);
                    },
                    icon: const Icon(Icons.check, color: Colors.lightGreenAccent),
                  ),

                ]),
              )
          );
        }
    );
  }

  void deleteWord([int posAdd = 0]){
    var pos = _panelController.getCursorPos(onlyCursor: true);

    bool cursor = false;
    if (pos < 0) {
      pos = _panelController.getFocusPos();
      if (pos < 0) return;
    } else {
      cursor = true;
    }

    pos += posAdd;

    if (pos < 0) return;

    if (cursor) {
      if (pos == 0) {
        _panelController.saveCursor(pos + 1);
      } else {
        _panelController.saveCursor(pos);
      }
    }

    var word = _panelController.getWord(pos);

    if (word.substring(0,1) == '\$') {
      word = word.substring(1);
    }

    final wordObject = getWordObjectFromLabel(word);
    if (wordObject != null) {
      if (wordObject.nonRemovable) return;
    }

    _panelController.deleteWord(pos);
    _panelController.refreshPanel();

    _basementController.addWord(word);
  }


  Future<String?> onDragBoxTap(String label, Offset position, Offset globalPosition) async {
    if (label.isEmpty) return label;

    if (label == JrfSpecText.wordKeyboard) {
      final inputValue = await wordInputDialog(context);
      if (inputValue.isEmpty) return null;
      return inputValue;
    }

    if (_textConstructorData.markStyle >= 0){
      if (label.substring(0, 1) == '\$') {
        label = label.substring(1);
      } else {
        label = '\$$label';
      }
    }

    return label;
  }

  Future<String?> onDragBoxLongPress(String label, Offset position, Offset globalPosition) async {
    return showPopupMenu(label, globalPosition);
  }

  Widget editPos() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        color: _editPosColor,
      ),
      width: _editPosWidth,
      height: _panelController.wordBoxHeight,
    );
  }

  Widget insertPos() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        color: _insertPosColor,
      ),
      width: _insertPosWidth,
      height: _panelController.wordBoxHeight,
    );
  }

  Widget onDragBoxBuild(BuildContext context, PanelBoxExt ext){ //String label, DragBoxSpec spec) {
    if (ext.spec == DragBoxSpec.editPos){
      return editPos();
    }

    if (ext.spec == DragBoxSpec.insertPos){
      return insertPos();
    }

    return labelWidget(context, ext.label, ext.spec);
  }

  Widget basementGroupHead(BuildContext context, String label) {
    return Text(label);
  }

  Widget onBasementBoxBuild(BuildContext context, GridBoxExt ext) {
    if (ext.isGroup) {
      return basementGroupHead(context, ext.label);
    }

    return labelWidget(context, ext.label, DragBoxSpec.none);
  }

  double internalBoxHeight() {
    if (_textConstructorData.boxHeight > 0) {
      return _textConstructorData.boxHeight - 2;
    }

    if (_panelController.wordBoxHeight == 0.0) return 20.0;
    return _panelController.wordBoxHeight - 2;
  }

  WordObject? getWordObjectFromLabel(String label) {
    if (label.substring(0, 1) != '#') return null;

    String objectName;
    if (label.substring(2,3) == '|') {
      objectName = label.substring(3);
    } else {
      objectName = label.substring(1);
    }

    final wordObject = _textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;
    return wordObject;
  }


  Widget labelWidget(BuildContext context, String label, DragBoxSpec spec) {
    if (label.isEmpty) return Container();

    var viewIndex = -1;

    int? styleIndex;

    if (label.substring(0, 1) == '\$' && _textConstructorData.markStyle >= 0) {
      styleIndex = _textConstructorData.markStyle;
      label = label.substring(1);
    }

    if (label.substring(0, 1) == '#') {
      String objectName;
      if (label.substring(2,3) == '|') {
        objectName = label.substring(3);
        viewIndex = int.parse(label.substring(1,2));
      } else {
        objectName = label.substring(1);
      }

      final wordObject = _textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;

      if (viewIndex < 0) {
        viewIndex = wordObject.viewIndex;
      }

      final viewStr = wordObject.views[viewIndex];

      return getObjectViewWidget(context, objectName: objectName, viewStr: viewStr, styleIndex: styleIndex, spec: spec );
    }

    return getObjectViewWidget(context, label: label, styleIndex: styleIndex, spec : spec );
  }

  Widget getObjectViewWidget(BuildContext context, {
    String      label      = '',
    String      objectName = '',
    String      viewStr    = '',
    int?        styleIndex ,
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

    var outStr = '';

    var localStyleIndex = -1;

    if (objectName.isNotEmpty) {
      final viewSplit1 = viewStr.split('|');
      if (viewSplit1.length == 1) {
        outStr = viewSplit1[0];
      } else {
        outStr = viewSplit1[1];

        final viewSplit2 = viewSplit1[0].split('/');
        final styleIndexStr = viewSplit2[0];
        if (styleIndexStr.isNotEmpty) {
          localStyleIndex = int.parse(styleIndexStr);
        }
        if (viewSplit2.length > 1) {
          menuText = viewSplit2[1];
        }
      }

      if (outStr.isEmpty) {
        outStr = objectName;
      }
    }

    if (styleIndex != null) {
      localStyleIndex = styleIndex;
    }

    if (localStyleIndex >= 0) {
      final styleStr = _textConstructorData.styles[localStyleIndex];
      final subStyleList = styleStr.split(',');

      for (var subStyle in subStyleList) {
        final subStyleStr = subStyle.trim().toLowerCase();
        final subStyleLen = subStyleStr.length;

        if (subStyleLen == 1) {
          if (subStyleStr == 'b') {
            textStyleBold = true;
          }
          if (subStyleStr == 'i') {
            textStyleItalic = true;
          }
        }

        if (subStyleLen == 3) {
          final formatCh = subStyleStr.substring(0,1);
          final formatId = subStyleStr.substring(0,2);
          final colorKey = subStyleStr.substring(2,3);

          if (formatId == 'cc') {
            textColor = _colorMap[colorKey]!;
          }
          if (formatId == 'bc') {
            backgroundColor = _colorMap[colorKey]!;
          }
          if (formatId == 'fc') {
            borderColor = _colorMap[colorKey]!;
          }

          if (formatCh == 'l') {
            linePos = TextDecoration.underline;
            lineColor = _colorMap[colorKey]!;

            if (formatId == 'l_') {
              lineStyle = TextDecorationStyle.solid;
            }
            if (formatId == 'l~') {
              lineStyle = TextDecorationStyle.wavy;
            }
            if (formatId == 'l=') {
              lineStyle = TextDecorationStyle.double;
            }
            if (formatId == 'l-') {
              lineStyle = TextDecorationStyle.dashed;
            }
            if (formatId == 'l.') {
              lineStyle = TextDecorationStyle.dotted;
            }
          }

          if (formatCh == 'd') {
            linePos = TextDecoration.lineThrough;
            lineColor = _colorMap[colorKey]!;

            if (formatId == 'd=') {
              lineStyle = TextDecorationStyle.double;
            }
            if (formatId == 'd-') {
              lineStyle = TextDecorationStyle.solid;
            }
          }
        }

      }
    }

    if (label.isNotEmpty) {
      outStr = label;
    }

    if (forPopup && menuText.isNotEmpty) {
      outStr = menuText;
    }

    if (spec == DragBoxSpec.move) {
      backgroundColor = _colorWordMove;
    }
    if (spec == DragBoxSpec.canDrop) {
      backgroundColor = _colorWordCanDrop;
    }
    if (spec == DragBoxSpec.focus) {
      borderColor = _focusBorderColor;
      borderWidth = _focusBorderWidth;
    }

    Widget? retWidget;

    if (widget.onBuildViewStrWidget != null) {
      final buildWidget = widget.onBuildViewStrWidget!.call(context, viewStr, spec, textColor, backgroundColor);

      if (buildWidget != null) {
        retWidget = SizedBox(
            height : internalBoxHeight(),
            child     : buildWidget
        );
      }
    }

    if (retWidget == null && viewStr == JrfSpecText.wordKeyboard) {
      retWidget = SizedBox(
          height : internalBoxHeight(),
          child  : Icon(Icons.keyboard_alt_outlined, color: textColor)
      );
    }

    retWidget ??= Container(
        color: backgroundColor,
        child: Text(
          outStr,
          style: TextStyle(
            color: textColor,

            decoration     : linePos,
            decorationColor: lineColor,
            decorationStyle: lineStyle,

            fontSize: _fontSize,
            fontWeight: textStyleBold? FontWeight.bold : null,
            fontStyle: textStyleItalic? FontStyle.italic : null,
          ),
        ),
    );

    if (forPopup) {
      return makeDecoration(
        child           : retWidget,
        borderColor     : _borderColor,
        borderWidth     : _borderWidth,
        backgroundColor : backgroundColor,
      );
    }

    return makeDecoration(
      child           : retWidget,
      borderColor     : borderColor,
      borderWidth     : borderWidth,
      backgroundColor : backgroundColor,
    );
  }

  Widget makeDecoration({
    required Widget child,
    required Color  borderColor,
    required double borderWidth,
    required Color  backgroundColor,
  }){
    return  Container(
      height:  _textConstructorData.boxHeight > 0 ? _textConstructorData.boxHeight : null,
      padding: const EdgeInsets.only(left: 10, right: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        color: backgroundColor,
      ),
      child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: child
      ),
    );
  }

  Future<String?> showPopupMenu(String label, Offset position) async {
    if (label.isEmpty) return null;
    if (label.substring(0, 1) != '#') return null;

    String objectName;
    if (label.substring(2,3) == '|') {
      objectName = label.substring(3);
    } else {
      objectName = label.substring(1);
    }

    final wordObject = _textConstructorData.objects.firstWhereOrNull((wordObject) => wordObject.name == objectName)!;

    final popupItems = <PopupMenuEntry<String>>[];

    for ( var i = 0; i < wordObject.views.length; i++ ) {
      final viewStr = wordObject.views[i];
      popupItems.add( PopupMenuItem(
          value: '#$i|$objectName',
          padding: EdgeInsets.zero,
          child: Center(child: getObjectViewWidget(context, objectName: objectName, viewStr: viewStr, forPopup: true))
      ));
    }

    final value = await showMenu<String>(
      context  : context,
      position : RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items    : popupItems,
      shape: const RoundedRectangleBorder( borderRadius: BorderRadius.all(Radius.circular(5)) ),
    );

    return value;
  }

  void onBasementBoxTap(DragBoxInfo<GridBoxExt> boxInfo, Offset position) {
    final curPos = _panelController.getCursorPos(lastPostIfNot: true);
    _panelController.saveCursor();
    _panelController.insertWord(curPos, boxInfo.data.ext.label);
    _panelController.refreshPanel();

    if (_textConstructorData.notDelFromBasement) return;

    boxInfo.setState(visible: false);
    _basementController.refresh();
  }

  Future<String> wordInputDialog(BuildContext context) async {
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

    if (result != null && result) return word;

    return '';
  }

}
