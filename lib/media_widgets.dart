import 'dart:convert';

import 'parse_pack_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'audio_button.dart';
import 'audio_widget.dart';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'html_widget.dart';
import 'html_widget_web.dart';

enum UrlType {
  httpUrl,
  parseTextUrl,
  localPath
}

UrlType getUrlType(String url) {
  if (url.startsWith('text:')) {
    return UrlType.parseTextUrl;
  }
  final prefix = url.split('://').first.toLowerCase();
  if (["http", "https"].contains(prefix)) return UrlType.httpUrl;
  return UrlType.localPath;
}

Future<void> playAudioUrl(String fileUrl) async {
  final urlType = getUrlType(fileUrl);
  if ( urlType == UrlType.httpUrl ) {
    playAudioNet(fileUrl);
    return;
  }
  if ( urlType == UrlType.localPath ) {
    playAudioFile(fileUrl);
    return;
  }
}

Widget audioPanelFromUrl(String fileUrl, key){
  final urlType = getUrlType(fileUrl);

  if ( urlType == UrlType.httpUrl ) {
    return AudioPanelWidget(
      key     : ValueKey(key),
      httpUrl : fileUrl
    );
  }

  if ( urlType == UrlType.localPath ) {
    final audioFile = File(fileUrl);
    if (audioFile.existsSync()) {
      return AudioPanelWidget(
        key:  ValueKey(key),
        localFilePath : fileUrl
      );
    }
  }

  return Container();
}

Widget audioButtonFromUrl(String fileUrl, Color color){
  final urlType = getUrlType(fileUrl);

  if ( urlType == UrlType.httpUrl ) {
    return SimpleAudioButton(
      httpUrl : fileUrl,
      color: color,
    );
  }

  if ( urlType == UrlType.localPath ) {
    final audioFile = File(fileUrl);
    if (audioFile.existsSync()) {
      return SimpleAudioButton(
        localFilePath : fileUrl,
        color: color,
      );
    }
  }

  return Container();
}

Widget imageFromUrl(String fileUrl){
  final urlType = getUrlType(fileUrl);

  if ( urlType == UrlType.httpUrl ) {
    return Image.network(fileUrl);
  }

  if ( urlType == UrlType.localPath ) {
    final imgFile = File(fileUrl);
    if (imgFile.existsSync()) {
      return Image.file(imgFile);
    }
  }

  return Container();
}

Widget htmlView(String html, [String? sourceDir]) {
  if (kIsWeb) {
    return HtmlViewWidgetWeb(html: html);
  }
  return HtmlViewWidget(html: html, filesDir: sourceDir!);
}

Future<String?> getTextFromUrl(String fileUrl) async {
  final urlType = getUrlType(fileUrl);

  if ( urlType == UrlType.parseTextUrl ) {
    final text = await getTextFromParseTextUrl(fileUrl);
    return text;
  }

  if ( urlType == UrlType.httpUrl ) {
    final response = await http.get(Uri.parse(fileUrl));
    final text = utf8.decode(response.bodyBytes);
    return text;
  }

  if ( urlType == UrlType.localPath ) {
    final textFile = File(fileUrl);
    if (textFile.existsSync()) {
      return await textFile.readAsString();
    }
  }

  return null;
}

