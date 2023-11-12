import 'dart:async';
import 'package:flutter/services.dart';

class PlatformService{
  static const platform = MethodChannel('com.dkiyanov.decard');

  static Future<String> getDeviceID() async {
    try {
      final String result = await platform.invokeMethod('getDeviceID');
      return result;
    } on PlatformException {
      return '';
    }
  }
}