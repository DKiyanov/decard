import 'package:flutter/material.dart';

class SimpleMenuItem {
  final Widget child;
  final VoidCallback onPress;

  SimpleMenuItem({required this.child, required this.onPress});
}

Widget longPressMenu({
  required BuildContext context,
  required Widget child,
  required List<SimpleMenuItem> menuItemList
}) {

  return GestureDetector(
    child: child,
    onLongPressStart: (details) async {
      final renderBox = Overlay.of(context)?.context.findRenderObject() as RenderBox;
      final tapPosition = renderBox.globalToLocal(details.globalPosition);

      final menuEntryList =  menuItemList.map<PopupMenuItem<VoidCallback>>((menuItem) => PopupMenuItem(
        value: menuItem.onPress,
        child: menuItem.child,
      )).toList();

      final value = await showMenu<VoidCallback>(
        context: context,
        position: RelativeRect.fromLTRB(tapPosition.dx, tapPosition.dy, tapPosition.dx, tapPosition.dy),
        items: menuEntryList,
      );

      if (value != null) {
        value.call();
      }
    },
  );
}

Widget popupMenu({
  required Widget icon,
  required List<SimpleMenuItem> menuItemList
}){
  return PopupMenuButton<VoidCallback>(
    icon: icon,
    itemBuilder: (context) {
      return menuItemList.map<PopupMenuItem<VoidCallback>>((menuItem) => PopupMenuItem<VoidCallback>(
        value: menuItem.onPress,
        child: menuItem.child,
      )).toList();
    },
    onSelected: (value) async {
      value.call();
    },
  );
}