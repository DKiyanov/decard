import 'package:flutter/material.dart';

Widget intFiled(TextEditingController tec) {
  return TextField (
    controller: tec,
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
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
