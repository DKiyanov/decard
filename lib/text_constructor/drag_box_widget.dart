import 'package:flutter/material.dart';

typedef DragBoxBuilder<T> = Widget Function(BuildContext context, T ext);


class DragBoxData<T>{
  Offset position;
  bool   visible;
  T      ext;

  DragBoxData({
    this.position =  const Offset(0.0, 0.0),
    this.visible  = true,
    required this.ext,
  });
}

class DragBoxInfo<T>{
  final DragBox widget;
  final DragBoxData<T> data;

  DragBoxInfo({required this.widget, required this.data});

  Size size = Size.zero;
  Rect get rect => Rect.fromLTWH(data.position.dx, data.position.dy, size.width, size.height);

  void setState({
    Offset?      position,
    bool?        visible,
    T?           ext,
  }){
    if (position != null) {
      data.position = position;
    }
    if (visible != null) {
      data.visible = visible;
    }
    if (ext != null) {
      data.ext = ext;
    }

    final boxKey = widget.key as GlobalKey<DragBoxState>;
    if (boxKey.currentState != null && boxKey.currentState!.mounted) {
      boxKey.currentState!.setState(() {});
    }
  }

  void refreshSize() {
    final boxKey = widget.key as GlobalKey<DragBoxState>;
    final renderBox = boxKey.currentContext!.findRenderObject() as RenderBox;
    size = renderBox.size;
  }

  static DragBoxInfo<T> create<T>({required DragBoxBuilder<T> builder, required T ext}){
    final boxData = DragBoxData<T>(ext: ext);

    return DragBoxInfo<T>(
      widget : DragBox<T>(
          data    : boxData,
          onBuild : builder,
          key     : GlobalKey<DragBoxState>()
      ),

      data : boxData,
    );
  }
}

class DragBox<T> extends StatefulWidget {
  final DragBoxData<T> data;
  final DragBoxBuilder<T> onBuild;

  const DragBox({required this.data, required this.onBuild, Key? key})  : super(key: key);

  @override
  State<DragBox<T>> createState() => DragBoxState<T>();
}

class DragBoxState<T> extends State<DragBox<T>> {
  @override
  Widget build(BuildContext context) {
    if (!widget.data.visible){
      return Positioned(
          left : 0,
          top  : 0,
          child: Container()
      );
    }

    return Positioned(
        left  : widget.data.position.dx,
        top   : widget.data.position.dy,
        child : widget.onBuild.call(context, widget.data.ext)
    );
  }
}
