import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'boxes_area.dart';
import 'drag_box_widget.dart';

typedef GridDragBoxTap = void Function(DragBoxInfo<GridBoxExt> boxInfo, int boxInfoIndex, Offset position, Offset globalPosition);
typedef OnChangeHeight = void Function(double newHeight);

class GridBoxExt{
  String label;
  final bool isGroup;
  DragBoxSpec spec;
  GridBoxExt({required this.label, this.isGroup = false, this.spec = DragBoxSpec.none});
}

class WordGridInfo{
  String label;
  final bool isGroup;
  bool visible;
  WordGridInfo({required this.label, required this.isGroup, required this.visible});
}

class WordGridController {
  _WordGridState? _gridState;

  String _text = '';

  WordGridController(String text){
    _text = text;
  }

  void addWord(String word) {
    if (_gridState == null) return;
    if (!_gridState!.mounted) return;

    _gridState!._addWord(word);
  }

  void refresh() {
    if (_gridState == null) return;
    if (!_gridState!.mounted) return;

    _gridState!._refresh();
  }

  String getVisibleWords() {
    if (_gridState == null) return '';
    if (!_gridState!.mounted) return '';

    return _gridState!._getVisibleWords();
  }

  void setVisibleWords(String words) {
    if (_gridState == null) return;
    if (!_gridState!.mounted) return;

    _gridState!._setVisibleWords(words);
  }

  List<WordGridInfo>? getWordList() {
    if (_gridState == null) return null;
    if (!_gridState!.mounted) return null;

    return _gridState!._getWordList();
  }

  void setWordList(List<WordGridInfo> wordList) {
    if (_gridState == null) return;
    if (!_gridState!.mounted) return;

    _gridState!._setWordList(wordList);
  }

  String? getText() {
    if (_gridState == null) return null;
    if (!_gridState!.mounted) return null;

    return _gridState!._getText();
  }

  void hideFocus() {
    if (_gridState == null) return;
    if (!_gridState!.mounted) return;

    _gridState!._hideFocus();
  }

  void setFocus(int index) {
    if (_gridState == null) return;
    if (!_gridState!.mounted) return;

    _gridState!._setFocus(index);
  }

  int? getFocusIndex() {
    if (_gridState == null) return null;
    if (!_gridState!.mounted) return null;

    return _gridState!._getFocusIndex();
  }

  void setLabel(int index, String label) {
    if (_gridState == null) return;
    if (!_gridState!.mounted) return;

    _gridState!._setLabel(index, label);
  }
}

class WordGrid extends StatefulWidget {
  final WordGridController controller;
  final DragBoxBuilder<GridBoxExt>  onDragBoxBuild;
  final GridDragBoxTap? onDragBoxTap;
  final GridDragBoxTap? onDragBoxLongPress;
  final OnChangeHeight? onChangeHeight;
  final VoidCallback?   onChangeBasement;
  final double          lineSpacing;

  const WordGrid({
    required this.controller,
    required this.onDragBoxBuild,
    this.onDragBoxTap,
    this.onDragBoxLongPress,
    this.onChangeHeight,
    this.onChangeBasement,
    this.lineSpacing = 5,

    Key? key
  }) : super(key: key);

  @override
  State<WordGrid> createState() => _WordGridState();
}

class _WordGridState extends State<WordGrid> {
  final _boxInfoList = <DragBoxInfo<GridBoxExt>>[];
  late BoxesAreaController<GridBoxExt> _boxAreaController;

  final _initHideList = <DragBoxInfo>[];

  double _width  = 0.0;
  double _height = 0.0;

  late  DragBoxInfo<GridBoxExt> _testBox;
  double _minBoxHeight = 0.0;

  @override
  void initState() {
    super.initState();

    _testBox = _createDragBoxInfo('Tp');

    _setText(widget.controller._text);
    _boxAreaController = BoxesAreaController(_boxInfoList,
      techBoxInfoList : [
        _testBox,
      ]
    );
  }

  void _setText(String text){
    _boxInfoList.clear();

    final regexp = RegExp(r'<\|.*?\|>');
    final matches = regexp.allMatches(text);

    int pos = 0;
    for (var element in matches) {
      if (element.start > pos) {
        final prevText = text.substring(pos, element.start);
        _addText(prevText);
      }

      final groupWord = text.substring(element.start+2, element.end-2);

      _boxInfoList.add(
        DragBoxInfo.create<GridBoxExt>(
          builder: widget.onDragBoxBuild,
          ext: GridBoxExt(label: groupWord, isGroup: true)
        )
      );

      pos = element.end;
    }

    final endText = text.substring(pos);
    _addText(endText);

    widget.onChangeBasement?.call();
  }

  void _addText(String str) {
    final wordList = <String>[];

    final subStrList = str.split("'");

    bool solid = false;

    for (var subStr in subStrList) {
      if (solid) {
        wordList.add(subStr);
      } else {
        wordList.addAll(subStr.split(' '));
      }

      solid = !solid;
    }

    for (var word in wordList) {
      if (word.isNotEmpty) {
        var hide = false;
        if (word.substring(0,1) == '~'){
          word = word.substring(1);
          hide = true;
        }

        final boxInfo = DragBoxInfo.create<GridBoxExt>(
          builder: widget.onDragBoxBuild,
          ext: GridBoxExt(label: word),
        );

        _boxInfoList.add(boxInfo);

        if (hide) {
          _initHideList.add(boxInfo);
        }

      }
    }
  }

  void _putBoxesInPlaces(double panelWidth){
    if (_boxInfoList.isEmpty) return;

    if (_initHideList.isNotEmpty) {
      for (var boxInfo in _boxInfoList) {
        if (_initHideList.contains(boxInfo)) {
          boxInfo.setState(visible: false);
        }
      }

      _initHideList.clear();
    }

    for (var boxInfo in _boxInfoList) {
      if (boxInfo.size.height < _minBoxHeight && !boxInfo.data.ext.isGroup) {
        boxInfo.size = Size(boxInfo.size.width, _minBoxHeight);
      }
    }

    _height = 0.0;

    if (!_boxInfoList.first.data.ext.isGroup) {
      _putBoxesGroup(0, panelWidth);
    }

    for (var i = 0; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      if (!boxInfo.data.ext.isGroup) continue;

      if (!_groupIsVisible(i + 1)) {
        boxInfo.setState(visible: false);
        continue;
      }

      boxInfo.setState(visible: true, position: Offset(panelWidth / 2 - boxInfo.size.width / 2, _height));

      _height += boxInfo.size.height;

      _putBoxesGroup(i + 1, panelWidth);
    }
  }

  bool _groupIsVisible(int fromIndex) {
    for (var i = fromIndex; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      if (boxInfo.data.ext.isGroup) {
        return false;
      }

      if (boxInfo.data.visible) return true;
    }

    return false;
  }

  void _putBoxesGroup(int fromIndex, double panelWidth) {
    // цель добиться минимального количества строк при максимальной ширине столбцов
    // и по возможности таблице подобного отображения
    // сильно длинные слова могут занимать несколько ячеек

    // рассчитываем среднюю и максимальную ширину столбца (слова)
    // далее двигаеся с небольшим икриментом от средней к максимальной
    // ловим минимальное количеств строк

    int toIndex = 0;
    int count = 0;
    double maxWidth = 0.0;
    double midWidth = 0.0;

    for (var i = fromIndex; i < _boxInfoList.length; i++) {
      final boxInfo = _boxInfoList[i];
      if (boxInfo.data.ext.isGroup) {
        toIndex = i - 1;
        break;
      }

      if (maxWidth < boxInfo.size.width) {
        maxWidth = boxInfo.size.width;
      }

      midWidth += boxInfo.size.width;
      count ++;
    }

    if (count == 0) return;

    if (toIndex == 0) {
      toIndex = _boxInfoList.length - 1;
    }

    midWidth = (midWidth / count).truncateToDouble();

    if (maxWidth > panelWidth) {
      maxWidth = panelWidth;
    }

    maxWidth = maxWidth.truncateToDouble() + 1;

    double bestLineCount = 100000000;
    double bestColumnWidth = 0.0;

    for (double columnWidth = midWidth; columnWidth <= maxWidth; columnWidth = columnWidth + 0.1 ) {
      final lineCount = _getGroupLineCount(fromIndex, toIndex, columnWidth, panelWidth);

      if (bestLineCount >= lineCount) {
        bestLineCount   = lineCount;
        bestColumnWidth = columnWidth;
      }
    }

    final columnCount = panelWidth ~/ bestColumnWidth;
    bestColumnWidth = panelWidth / columnCount;
//    bestColumnWidth --;

    _putBoxesGroupOk(fromIndex, toIndex, bestColumnWidth, panelWidth);
  }

  double _getBoxGridWidth(double boxWidth, double columnWidth, double panelWidth) {
    double boxGridWidth = 0.0;

    if (boxWidth <= columnWidth) {
      boxGridWidth = columnWidth;
    } else {
      boxGridWidth = (boxWidth ~/ columnWidth) * columnWidth;
      if (boxGridWidth < boxWidth) {
        boxGridWidth += columnWidth;
      }

      if (boxGridWidth > panelWidth) {
        boxGridWidth = panelWidth;
      }
    }

    return boxGridWidth;
  }

  void _putBoxesGroupOk(int fromIndex, int toIndex, double columnWidth, double panelWidth) {
    var position = Offset(0, _height);
    Offset nextPosition;

    double lineHeight = 0.0;
    bool lineVisible = false;

    for (var i = fromIndex; i <= toIndex; i++) {
      final boxInfo = _boxInfoList[i];

      final boxWidth = _getBoxGridWidth(boxInfo.size.width, columnWidth, panelWidth);

      if (lineHeight < boxInfo.size.height) {
        lineHeight = boxInfo.size.height;
      }

      nextPosition = Offset(position.dx + boxWidth, position.dy);
      if (nextPosition.dx > panelWidth){
        if (lineVisible) {
          position = Offset(0, position.dy + lineHeight + widget.lineSpacing);
        } else {
          position = Offset(0, position.dy);
        }

        nextPosition = Offset(position.dx + boxWidth, position.dy);
        lineVisible = false;

        if (i < toIndex) {
          lineHeight = boxInfo.size.height;
        }
      }

      if (boxInfo.data.visible) {
        lineVisible = true;
      }

      boxInfo.setState(position: position);

      position = nextPosition;
    }

    _height = position.dy + lineHeight;
  }

  double _getGroupLineCount(int fromIndex, int toIndex, double columnWidth, double panelWidth) {
    double lineCount = 1;

    double lineWidth = 0;
    int penalty = 0;

    for (var i = fromIndex; i <= toIndex; i++) {
      final boxInfo = _boxInfoList[i];

      final boxWidth = _getBoxGridWidth(boxInfo.size.width, columnWidth, panelWidth);
      if (boxWidth > columnWidth) {
        penalty ++;
      }

      lineWidth += boxWidth;

      if (lineWidth > panelWidth) {
        lineCount ++;
        lineWidth = boxWidth;
      }
    }

    return lineCount + (penalty * 0.3);
  }

  @override
  Widget build(BuildContext context) {
    widget.controller._gridState = this;

    return BoxesArea<GridBoxExt>(
      controller: _boxAreaController,
      calcMinimalEmptyHeight: false,

      onRebuildLayout: (BoxConstraints viewportConstraints, List<DragBoxInfo<GridBoxExt>> boxInfoList) {
        if (_width != viewportConstraints.maxWidth) {
          _width = viewportConstraints.maxWidth;
          _getTechBoxSizes();
        }

        _putBoxesInPlaces(viewportConstraints.maxWidth);
      },

      onBoxTap: (DragBoxInfo<GridBoxExt>? boxInfo, Offset position, Offset globalPosition) async {
        if (boxInfo == null) return;
        final boxInfoIndex = _boxInfoList.indexOf(boxInfo);
        widget.onDragBoxTap!.call(boxInfo, boxInfoIndex, boxInfo.data.position, globalPosition);
      },

      onBoxLongPress: (DragBoxInfo<GridBoxExt>? boxInfo, Offset position, Offset globalPosition) async {
        if (boxInfo == null || widget.onDragBoxLongPress == null) return;
        final boxInfoIndex = _boxInfoList.indexOf(boxInfo);
        widget.onDragBoxLongPress!.call(boxInfo, boxInfoIndex, boxInfo.data.position, globalPosition);
      },

      onChangeSize: (double prevWidth, double newWidth, double prevHeight, double newHeight){
        if (prevHeight != newHeight) {
          widget.onChangeHeight?.call(newHeight);
        }
      },
    );
  }

  void _getTechBoxSizes() {
    if (_minBoxHeight == 0.0) {
      _testBox.refreshSize();
      _minBoxHeight = _testBox.size.height;
      _testBox.setState(visible: false);
    }
  }

  void _addWord(String word) {
    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo) => boxInfo.data.ext.label == word && !boxInfo.data.visible);
    if (boxInfo != null) {
      boxInfo.setState(visible: true);
    } else {
      if (!_boxInfoList.any((boxInfo) => boxInfo.data.ext.label == word)) {
        _boxInfoList.add(
            _createDragBoxInfo(word)
        );
      }
    }

    widget.onChangeBasement?.call();
    _boxAreaController.refresh();
  }

  String _getVisibleWords() {
    String result = '';

    for (var boxInfo in _boxInfoList) {
      if (!boxInfo.data.visible) continue;
      if (result.isEmpty) {
        result = boxInfo.data.ext.label;
      } else {
        result = '$result\n${boxInfo.data.ext.label}';
      }
    }

    return result;
  }

  void _setVisibleWords(String words) {
    final wordList = words.isEmpty ? [] : words.split('\n');

    for (var boxInfo in _boxInfoList) {
      bool newVisible = false;

      final wordIndex = wordList.indexWhere((word) => word == boxInfo.data.ext.label);
      if (wordIndex >= 0) {
        wordList.removeAt(wordIndex);
        newVisible = true;
      }

      if (boxInfo.data.visible != newVisible) {
        boxInfo.setState(visible: newVisible);
      }
    }

    for (var word in wordList) {
      _boxInfoList.add(
         _createDragBoxInfo(word)
      );
    }

    widget.onChangeBasement?.call();
    _refresh();
  }

  List<WordGridInfo> _getWordList() {
    final result = <WordGridInfo>[];

    for (var boxInfo in _boxInfoList) {
      result.add(WordGridInfo(
        label   : boxInfo.data.ext.label,
        isGroup : boxInfo.data.ext.isGroup,
        visible : boxInfo.data.visible
      ));
    }

    return result;
  }

  void _setWordList(List<WordGridInfo> wordList) {
    _boxInfoList.clear();
    for (var wordInfo in wordList) {
      if (wordInfo.isGroup) {
        _boxInfoList.add(
          DragBoxInfo.create<GridBoxExt>(
            builder: widget.onDragBoxBuild,
            ext: GridBoxExt(label: wordInfo.label, isGroup: true)
          )
        );
      } else {
        _boxInfoList.add(
          DragBoxInfo.create<GridBoxExt>(
            builder: widget.onDragBoxBuild,
            ext: GridBoxExt(label: wordInfo.label),
          )
        );
      }
    }

    widget.onChangeBasement?.call();
    _refresh();
  }

  void _hideFocus() {
    final focusBoxInfo = _boxInfoList.firstWhereOrNull((boxInfo) => boxInfo.data.ext.spec == DragBoxSpec.focus);
    if (focusBoxInfo == null) return;
    focusBoxInfo.data.ext.spec = DragBoxSpec.none;
    focusBoxInfo.setState();
  }

  void _setFocus(int index) {
    _hideFocus();
    final boxInfo = _boxInfoList[index];
    boxInfo.data.ext.spec = DragBoxSpec.focus;
    boxInfo.setState();
  }

  int? _getFocusIndex() {
    return _boxInfoList.indexWhere((boxInfo) => boxInfo.data.ext.spec == DragBoxSpec.focus);
  }

  void _setLabel(int index, String label) {
    final boxInfo = _boxInfoList[index];
    boxInfo.data.ext.label = label;
    widget.onChangeBasement?.call();
    boxInfo.setState();
  }

  String _getText() {
    final resStrList = <String>[];

    for (var boxInfo in _boxInfoList) {
      if (boxInfo.data.ext.isGroup) {
        resStrList.add('<|${boxInfo.data.ext.label}|>');
        continue;
      }

      String str = boxInfo.data.ext.label;
      if (str.contains(' ')) str = "'$str'";
      if (!boxInfo.data.visible) str = '~$str';
      resStrList.add(str);
    }

    return resStrList.join(' ');
  }

  DragBoxInfo<GridBoxExt> _createDragBoxInfo(String word){
    return DragBoxInfo.create<GridBoxExt>(
      builder: widget.onDragBoxBuild,
      ext: GridBoxExt(label: word),
    );
  }

  void _refresh() {
    _boxAreaController.refresh();
  }
}