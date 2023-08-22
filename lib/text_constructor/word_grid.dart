import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'boxes_area.dart';
import 'drag_box_widget.dart';

typedef DragBoxTap = void Function(DragBoxInfo<GridBoxExt> boxInfo, Offset position);
typedef OnChangeHeight = void Function(double newHeight);

class GridBoxExt{
  final String label;
  final bool isGroup;
  GridBoxExt({required this.label, this.isGroup = false});
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
}

class WordGrid extends StatefulWidget {
  final WordGridController controller;
  final DragBoxBuilder<GridBoxExt>  onDragBoxBuild;
  final DragBoxTap?     onDragBoxTap;
  final OnChangeHeight? onChangeHeight;
  final double          lineSpacing;

  const WordGrid({required this.controller, required this.onDragBoxBuild, this.onDragBoxTap, this.onChangeHeight, this.lineSpacing = 5, Key? key}) : super(key: key);

  @override
  State<WordGrid> createState() => _WordGridState();
}

class _WordGridState extends State<WordGrid> {
  final _boxInfoList = <DragBoxInfo<GridBoxExt>>[];
  late BoxesAreaController<GridBoxExt> _boxAreaController;
  bool _rebuildStrNeed = false;

  final _initHideList = <DragBoxInfo>[];

  double _width  = 0.0;
  double _height = 0.0;

  @override
  void initState() {
    super.initState();

    _setText(widget.controller._text);
    _boxAreaController = BoxesAreaController(_boxInfoList);
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

    _rebuildStrNeed = true;
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

    midWidth = midWidth / count;

    if (maxWidth > panelWidth) {
      maxWidth = panelWidth;
    }

    int bestLineCount = 100000000;
    double bestColumnWidth = 0.0;

    for (double columnWidth = midWidth; columnWidth <= maxWidth; columnWidth ++) {
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
          lineHeight = 0.0;
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

  int _getGroupLineCount(int fromIndex, int toIndex, double columnWidth, double panelWidth) {
    int lineCount = 1;

    double lineWidth = 0;

    for (var i = fromIndex; i <= toIndex; i++) {
      final boxInfo = _boxInfoList[i];

      final boxWidth = _getBoxGridWidth(boxInfo.size.width, columnWidth, panelWidth);

      lineWidth += boxWidth;

      if (lineWidth > panelWidth) {
        lineCount ++;
        lineWidth = boxWidth;
      }
    }

    return lineCount;
  }

  @override
  Widget build(BuildContext context) {
    widget.controller._gridState = this;

    return BoxesArea<GridBoxExt>(
      controller: _boxAreaController,

      onRebuildLayout: (BoxConstraints viewportConstraints, List<DragBoxInfo<GridBoxExt>> boxInfoList) {
        if (_width != viewportConstraints.maxWidth) {
          _width = viewportConstraints.maxWidth;
          _rebuildStrNeed = true;
        }

        if (!_rebuildStrNeed) return;
        _rebuildStrNeed = false;
        _putBoxesInPlaces(viewportConstraints.maxWidth);
      },

      onBoxTap: (DragBoxInfo<GridBoxExt>? boxInfo, Offset position) async {
        if (boxInfo == null) return;
        widget.onDragBoxTap!.call(boxInfo, boxInfo.data.position);
      },

      onChangeSize: (double prevWidth, double newWidth, double prevHeight, double newHeight){
        if (prevHeight != newHeight) {
          widget.onChangeHeight?.call(newHeight);
        }
      },
    );
  }

  void _addWord(String word) {
    final boxInfo = _boxInfoList.firstWhereOrNull((boxInfo) => boxInfo.data.ext.label == word && !boxInfo.data.visible);
    if (boxInfo != null) {
      boxInfo.setState(visible: true);
    } else {
      _boxInfoList.add(
          DragBoxInfo.create<GridBoxExt>(
            builder: widget.onDragBoxBuild,
            ext: GridBoxExt(label: word),
          )
      );
    }

    _rebuildStrNeed = true;
    _boxAreaController.refresh();
  }

  void _refresh() {
    _boxAreaController.refresh();
  }
}