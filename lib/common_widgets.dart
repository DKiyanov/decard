import 'package:flutter/material.dart';

Widget intFiled(TextEditingController tec) {
  return TextField (
    controller: tec,
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
    textAlign: TextAlign.right,
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
    ),
  );
}

Widget longPressMenu<T>({
  required BuildContext context,
  required Widget child,
  required List<PopupMenuEntry<T>> menuItemList,
  PopupMenuItemSelected? onSelect
}) {

  return GestureDetector(
    child: child,
    onLongPressStart: (details) async {
      final renderBox = Overlay.of(context)?.context.findRenderObject() as RenderBox;
      final tapPosition = renderBox.globalToLocal(details.globalPosition);

      final value = await showMenu<T>(
        context: context,
        position: RelativeRect.fromLTRB(tapPosition.dx, tapPosition.dy, tapPosition.dx, tapPosition.dy),
        items: menuItemList,
      );

      if (value != null && onSelect != null) {
        onSelect.call(value);
      }
    },
  );

}

void showHelp(BuildContext context, String help){
  showDialog(context: context, builder: (BuildContext context){
    return AlertDialog(
      content: Text(help),
      backgroundColor: Colors.yellowAccent,
    );
  });
}

