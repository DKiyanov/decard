import 'package:flutter/material.dart';

extension BuildContextExt on BuildContext {
  double get scale => Theme.of(this).textTheme.bodyMedium!.fontSize! / 14;
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.of(this).size;
}