import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'drag_box_widget.dart';

typedef DragBoxTap<T> = void Function(DragBoxInfo<T>? boxInfo, Offset position);
typedef AreaPan = Function(Offset position);

typedef OnChangeSize = void Function(double prevWidth, double newWidth, double prevHeight, double newHeight);
typedef OnRebuildLayout<T> = void Function(BoxConstraints viewportConstraints, List<DragBoxInfo<T>> boxInfoList);

class BoxesAreaController<T> {
  _BoxesAreaState<T>? _boxesAreaState;
  final List<DragBoxInfo<T>> boxInfoList;
  final List<DragBoxInfo<T>>? techBoxInfoList;

  BoxesAreaController(this.boxInfoList, {this.techBoxInfoList});

  void refresh() {
    if (_boxesAreaState == null) return;
    if (!_boxesAreaState!.mounted) return;

    _boxesAreaState!._refresh();
  }

  DragBoxInfo<T>? getBoxAtPos({Offset? position, Offset? globalPosition}) {
    if (_boxesAreaState == null) return null;
    if (!_boxesAreaState!.mounted) return null;

    return _boxesAreaState!._getBoxAtPos(position: position, globalPosition: globalPosition);
  }

  bool isHeightChanged() {
    if (_boxesAreaState == null) return false;
    if (!_boxesAreaState!.mounted) return false;

    return _boxesAreaState!._isHeightChanged();
  }
}

class BoxesArea<T> extends StatefulWidget {
  final BoxesAreaController<T> controller;
  final OnRebuildLayout<T>   onRebuildLayout;
  final DragBoxTap<T>?       onBoxTap;
  final OnChangeSize?     onChangeSize;

  final AreaPan? onPanStart;
  final AreaPan? onPanUpdate;
  final VoidCallback? onPanEnd;

  final DragBoxTap<T>? onBoxLongPress;
  final DragBoxTap<T>? onBoxDoubleTap;

  const BoxesArea({
    required this.controller,
    required this.onRebuildLayout,
    this.onBoxTap,
    this.onChangeSize,

    this.onBoxLongPress,
    this.onBoxDoubleTap,

    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,

    Key? key
  }) : super(key: key);

  @override
  State<BoxesArea<T>> createState() => _BoxesAreaState<T>();
}

class _BoxesAreaState<T> extends State<BoxesArea<T>> {
  late BoxesAreaController<T> _controller;
  final _stackKey = GlobalKey();
  bool  _starting = true;

  double _width = 0.0;
  double _height = 0.0;

  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  Widget build(BuildContext context) {
    widget.controller._boxesAreaState = this;

    final childList = _controller.boxInfoList.map((boxInfo)=>boxInfo.widget).toList();

    if (_controller.techBoxInfoList != null) {
      childList.addAll(_controller.techBoxInfoList!.map((boxInfo)=>boxInfo.widget).toList());
    }

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      WidgetsBinding.instance.addPostFrameCallback((_){

        if (_viewportSize.width != viewportConstraints.maxWidth || _viewportSize.height != viewportConstraints.maxHeight) {
          _viewportSize = Size(viewportConstraints.maxWidth, viewportConstraints.maxHeight);
          _calcSize(viewportConstraints);
        }

        if (_starting) {
          _calcSize(viewportConstraints);

          _starting = false;
          setState(() {});
        }

      });

      if (_starting) {
        return Offstage(
          child: Stack(
            children: childList,
          ),
        );
      }

      return SingleChildScrollView(
        child: GestureDetector(
          onTapUp: (details) => _onTapProcess(widget.onBoxTap, details.globalPosition),

          onLongPressStart: (details) => _onTapProcess(widget.onBoxLongPress, details.globalPosition),
          onDoubleTapDown:  (details) => _onTapProcess(widget.onBoxDoubleTap, details.globalPosition),

          onPanStart:       (details) => _onPanProcess(widget.onPanStart, details.globalPosition),
          onPanUpdate:      (details) => _onPanProcess(widget.onPanUpdate, details.globalPosition),
          onPanEnd:         (details) => widget.onPanEnd?.call(),

          child: SizedBox(
            height: _height,

            child: Stack(
              key : _stackKey,
              children: childList,
            ),
          ),
        ),
      );

    });
  }

  void _calcSize(BoxConstraints viewportConstraints) {
    for (var boxInfo in _controller.boxInfoList) {
      if (!boxInfo.data.visible) continue;
      boxInfo.refreshSize();
    }

    widget.onRebuildLayout.call(viewportConstraints, _controller.boxInfoList);

    double width  = 0.0;
    double height = 0.0;

    for (var boxInfo in _controller.boxInfoList) {
      if (!boxInfo.data.visible) continue;

      final right = boxInfo.data.position.dx + boxInfo.size.width;
      if (width < right) {
        width = right;
      }

      final bottom = boxInfo.data.position.dy + boxInfo.size.height;
      if (height < bottom) {
        height = bottom;
      }
    }

    if (_width != width || _height != height) {
      final prevWidth  = _width;
      final prevHeight = _height;

      _width  = width;
      _height = height;
      _starting = true;

      widget.onChangeSize?.call(prevWidth, width, prevHeight, height);
    }
  }

  bool _isHeightChanged() {
    double height = 0.0;

    for (var boxInfo in _controller.boxInfoList) {
      if (!boxInfo.data.visible) continue;

      final bottom = boxInfo.data.position.dy + boxInfo.size.height;
      if (height < bottom) {
        height = bottom;
      }
    }

    return height != _height;
  }

  RenderBox _getStackRenderBox(){
    return _stackKey.currentContext!.findRenderObject() as RenderBox;
  }

  Future<void> _onTapProcess(DragBoxTap<T>? tapEvent, Offset globalPosition) async {
    if (tapEvent == null) return;

    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(globalPosition);
    final boxInfo = _controller.boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position));

    tapEvent.call(boxInfo, position);
  }

  Future<void> _onPanProcess(AreaPan? panEvent, Offset globalPosition) async {
    if (panEvent == null) return;

    final renderBox = _getStackRenderBox();
    final position = renderBox.globalToLocal(globalPosition);

    panEvent.call(position);
  }

  void _refresh() {
    _starting = true;
    setState(() {});
  }

  DragBoxInfo<T>? _getBoxAtPos({Offset? position, Offset? globalPosition}) {
    if (position == null) {
      final renderBox = _getStackRenderBox();
      position = renderBox.globalToLocal(globalPosition!);
    }

    final boxInfo = _controller.boxInfoList.firstWhereOrNull((boxInfo)=>boxInfo.rect.contains(position!));
    return boxInfo;
  }
}