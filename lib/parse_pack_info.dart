import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:flutter_archive/flutter_archive.dart';

import 'db.dart';
import 'decardj.dart';
import 'loader.dart';
import 'local_pack_load.dart';

class WebPackInfo {
  final int    packId        ;
  final String title         ;
  final String guid          ;
  final int    version       ;
  final String author        ;
  final String site          ;
  final String email         ;
  final String tags          ;
  final String license       ;
  final int    targetAgeLow  ;
  final int    targetAgeHigh ;
  final DateTime? publicationMoment;
  final int    starsCount    ;
  final String userID        ;

  final tagList = <String>[];

  bool get published => publicationMoment != null;

  WebPackInfo({
    required this.packId       ,
    required this.title        ,
    required this.guid         ,
    required this.version      ,
    required this.author       ,
    required this.site         ,
    required this.email        ,
    required this.tags         ,
    required this.license      ,
    required this.targetAgeLow ,
    required this.targetAgeHigh,
    required this.publicationMoment ,
    required this.starsCount   ,
    required this.userID,
  }) {
    final prevTagList = tags.split(',');

    for (var tag in prevTagList) {
      tagList.add(tag.trim().toLowerCase());
    }
  }

  factory WebPackInfo.fromParse(ParseObject parseObject) {
    return WebPackInfo(
      packId        : parseObject.get<int>(WebPackFields.packId  )!,
      title         : parseObject.get<String>(DjfFile.title      )!,
      guid          : parseObject.get<String>(DjfFile.guid       )!,
      version       : parseObject.get<int>(DjfFile.version       )!,
      author        : parseObject.get<String>(DjfFile.author     )!.toLowerCase(),
      site          : parseObject.get<String>(DjfFile.site       )!,
      email         : parseObject.get<String>(DjfFile.email      )!,
      tags          : parseObject.get<String>(DjfFile.tags       )??'',
      license       : parseObject.get<String>(DjfFile.license    )??'',
      targetAgeLow  : parseObject.get<int>(DjfFile.targetAgeLow  )??0,
      targetAgeHigh : parseObject.get<int>(DjfFile.targetAgeHigh )??100,
      publicationMoment: parseObject.get<DateTime>(WebPackFields.publicationMoment),
      starsCount    : parseObject.get<int>(WebPackFields.starsCount)??0,
      userID        : parseObject.get<String>(WebPackFields.userID)!,
    );
  }
}

class WebPackListResult{
  List<WebPackInfo> packInfoList;
  List<MapEntry<String, int>> tagList;
  List<MapEntry<String, int>> authorList;
  int targetAgeLow;
  int targetAgeHigh;

  WebPackListResult({
    required this.packInfoList,
    required this.authorList,
    required this.tagList,
    required this.targetAgeLow,
    required this.targetAgeHigh,
  });
}

class WebPackUploadFileFields {
  static const String className = 'UploadWebFile';
  static const String userID    = 'UserID';
  static const String fileName  = 'FileName';
  static const String size      = 'Size';
  static const String content   = 'Content';
}

class WebPackFields {
  static const String className    = 'DecardFileHead';
  static const String packId       = 'packID';
  static const String content      = 'Content';
  static const String fileName     = 'FileName';
  static const String createdAt    = 'createdAt';
  static const String publicationMoment = 'PublicationMoment';
  static const String starsCount   = 'StarsCount';
  static const String userID       = 'UserID';
}

class WebPackSubFileFields {
  static const String className    = 'DecardFileSub';
  static const String packId       = 'packID';
  static const String file         = 'file';
  static const String path         = 'path';
  static const String isText       = 'isText';
  static const String textContent  = 'textContent';
}

class WebPackUserFilesFields {
  static const String className    = 'DecardUserFiles';
  static const String userID       = 'UserID';
  static const String packId       = 'packID';
}

class WebPackListManager {
  final _webPackInfoList = <WebPackInfo>[];
  bool _initialized = false;

  WebPackListManager();

  Future<void> init() async {
    if (_initialized) return;

    final query = QueryBuilder<ParseObject>(ParseObject(WebPackFields.className));
    query.whereGreaterThan(WebPackFields.publicationMoment, DateTime(2000));
    final parsePackList = await query.find();

    for (var parsePack in parsePackList) {
      _webPackInfoList.add(WebPackInfo.fromParse(parsePack));
    }

    _initialized = true;
  }

  Future<List<WebPackInfo>> getUserPackList(String userID) async {
    final result = <WebPackInfo>[];

    // other people's used packages
    {
      final query = QueryBuilder<ParseObject>(ParseObject(WebPackUserFilesFields.className));
      query.whereEqualTo(WebPackFields.userID, userID);
      final userPackList = await query.find();

      for (var userPack in userPackList) {
        final packId = userPack.get<int>(WebPackFields.packId)!;
        final webPackInfo = _webPackInfoList.firstWhereOrNull((webPackInfo) => webPackInfo.packId == packId);
        if (webPackInfo == null) continue;

        result.add(webPackInfo);
      }
    }

    // own user packages
    final query = QueryBuilder<ParseObject>(ParseObject(WebPackFields.className));
    query.whereEqualTo(WebPackFields.userID, userID);
    final parsePackList = await query.find();

    for (var parsePack in parsePackList) {
      final packId = parsePack.get<int>(WebPackFields.packId)!;
      final webPackInfo = _webPackInfoList.firstWhereOrNull((webPackInfo) => webPackInfo.packId == packId);
      if (webPackInfo != null) {
        result.add(webPackInfo);
        continue;
      }

      result.add(WebPackInfo.fromParse(parsePack));
    }

    return result;
  }

  Future<WebPackListResult> getPackList({String? title, List<String>? authorList, List<String>? tagList, int? targetAge}) async {
    final packInfoList = <WebPackInfo>[];
    final tagMap       = <String, int>{};
    final authorMap    = <String, int>{};
    int targetAgeLow   = 0;
    int targetAgeHigh  = 0;

    RegExp? titleRegexp;

    if (title != null && title.isNotEmpty) {
      final titleMask = '.*${title.replaceAll(r"/\s\s+/g", ' ').trim().replaceAll(' ', '.*')}.*';
      titleRegexp = RegExp(titleMask, caseSensitive: false);
    }

    for (var packInfo in _webPackInfoList) {
      if (titleRegexp != null) {
        if (!titleRegexp.hasMatch(packInfo.title)) continue;
      }

      if (authorList != null && authorList.isNotEmpty) {
        if (!authorList.contains(packInfo.author)) continue;
      }

      if (tagList != null && tagList.isNotEmpty) {
        bool skip = false;
        for (var tag in tagList) {
          if (!packInfo.tagList.contains(tag)) {
            skip = true;
            break;
          }
        }
        if (skip) continue;
      }

      if (targetAgeLow > packInfo.targetAgeLow) {
        targetAgeLow = packInfo.targetAgeLow;
      }
      if (targetAgeHigh < packInfo.targetAgeHigh) {
        targetAgeHigh = packInfo.targetAgeHigh;
      }

      if (targetAge != null && targetAge >= 0) {
        if (packInfo.targetAgeLow > targetAge || packInfo.targetAgeHigh < targetAge) {
          continue;
        }
      }

      packInfoList.add(packInfo);

      final count = authorMap[packInfo.author]??0;
      authorMap[packInfo.author] = count  + 1;

      for (var tag in packInfo.tagList) {
        final count = tagMap[tag]??0;
        tagMap[tag] = count + 1;
      }

    }

    final authorCountList = authorMap.entries.toList()..sort((e2, e1) => e1.value.compareTo(e2.value));
    final tagCountList    = tagMap.entries.toList()..sort((e2, e1) => e1.value.compareTo(e2.value));

    return WebPackListResult(
        packInfoList  : packInfoList,
        authorList    : authorCountList,
        tagList       : tagCountList,
        targetAgeLow  : targetAgeLow,
        targetAgeHigh : targetAgeHigh
    );
  }
}

Future<int?> loadWebPack(DbSource dbSource, int packId, {LoadPackAddInfoCallback? addInfoCallback, bool putFilesIntoLocalStore = false}) async {
  Map<String, String>? fileUrlMap;

  if (putFilesIntoLocalStore) {
    fileUrlMap = await _getPackSourceApp(packId);
  } else {
    fileUrlMap = await _getPackSourceWeb(packId);
  }

  if (fileUrlMap == null) return null;

  return await loadPack(dbSource, 'WebPack:$packId', fileUrlMap, addInfoCallback : addInfoCallback);
}

Future<Map<String, String>?> getPackSource(int packId, {bool putFilesIntoLocalStore = false}) async {
  if (putFilesIntoLocalStore) {
    return await _getPackSourceApp(packId);
  } else {
    return await _getPackSourceWeb(packId);
  }
}

Future<Map<String, String>?> _getPackSourceWeb(int packId) async {
  final query = QueryBuilder<ParseObject>(ParseObject(WebPackSubFileFields.className));
  query.whereEqualTo(WebPackSubFileFields.packId, packId);
  query.keysToReturn([WebPackSubFileFields.path, WebPackSubFileFields.file, WebPackSubFileFields.isText]);
  final sourceList = await query.find();

  final Map<String, String> fileUrlMap = {};

  for (var source in sourceList) {
    final path = source.get<String>(WebPackSubFileFields.path)!;
    final isText = source.get<bool>(WebPackSubFileFields.isText)??false;

    String url;

    if (isText) {
      url = 'text:$packId|$path';
    } else {
      if (kIsWeb) {
        url = source.get<ParseWebFile>(WebPackSubFileFields.file)!.url!;
      } else {
        url = source.get<ParseFile>(WebPackSubFileFields.file)!.url!;
      }
    }

    fileUrlMap[path] = url;
  }

  return fileUrlMap;
}

Future<String?> getTextFromParseTextUrl(String fileUrl) async {
  if (!fileUrl.startsWith('text:')) return null;
  final url = fileUrl.substring(5);
  final parts = url.split('|');

  final packId = int.parse(parts.first);
  final path = parts.last;

  final query = QueryBuilder<ParseObject>(ParseObject(WebPackSubFileFields.className));
  query.whereEqualTo(WebPackSubFileFields.packId, packId);
  query.whereEqualTo(WebPackSubFileFields.path  , path);
  query.whereEqualTo(WebPackSubFileFields.isText, true);
  query.keysToReturn([WebPackSubFileFields.textContent]);
  final row = await query.first();

  if (row == null) return '';

  final text = row.get<String>(WebPackSubFileFields.textContent)??'';
  return text;
}

class WebPackTextFile {
  final int packId;
  final String path;
  WebPackTextFile({required this.packId,required this.path});

  ParseObject? _parseObject;

  Future<void> _initParseObject() async {
    if (_parseObject != null) return;
    final query = QueryBuilder<ParseObject>(ParseObject(WebPackSubFileFields.className));
    query.whereEqualTo(WebPackSubFileFields.packId, packId);
    query.whereEqualTo(WebPackSubFileFields.path  , path);
    query.whereEqualTo(WebPackSubFileFields.isText, true);
    query.keysToReturn([WebPackSubFileFields.textContent]);
    _parseObject = await query.first();
  }

  Future<String> getText() async {
    if (_parseObject == null) {
      await _initParseObject();
    }

    final result = _parseObject!.get<String>(WebPackSubFileFields.textContent)??'';
    return result;
  }

  Future<void> setText(String newText) async {
    if (_parseObject == null) {
      await _initParseObject();
    }

    _parseObject!.set(WebPackSubFileFields.textContent, newText);
    await _parseObject!.save();
  }
}

Future<Map<String, String>?> _getPackSourceApp(int packId) async {
  final query = QueryBuilder<ParseObject>(ParseObject(WebPackFields.className));
  query.whereEqualTo(WebPackFields.packId, packId);
  query.keysToReturn([WebPackFields.fileName, WebPackFields.content]);
  final packInfo = await query.first();

  if (packInfo == null) return null;

  final packFileName = packInfo.get<String>(WebPackFields.fileName)!;
  final fileExt = path_util.extension(packFileName).toLowerCase();
  if (!DjfFileExtension.values.contains(fileExt)) {
    return null;
  }

  Directory appDocDir = await getApplicationDocumentsDirectory();
  final packPath = path_util.join(appDocDir.path, 'pack_$packId');

  final dir = Directory(packPath);

  if (!dir.existsSync()) {
    final content = packInfo.get<ParseFile>(WebPackFields.content)!;
    await content.loadStorage();
    if (content.file == null) {
      await content.download();
    }

    await dir.create();

    if (fileExt == DjfFileExtension.zip) {
      await ZipFile.extractToDirectory(
          zipFile: content.file!, destinationDir: dir);
    }
    if (fileExt == DjfFileExtension.json) {
      await content.file!.copy(path_util.join(dir.path, packFileName));
    }

    content.file!.delete();
  }

  final dirSource = await getDirSource(packPath);
  return dirSource;
}

Future<String> addFileToPack(int packId, String filePath, Uint8List fileContent) async {
  final query = QueryBuilder<ParseObject>(ParseObject(WebPackSubFileFields.className));
  query.whereEqualTo(WebPackFields.packId, packId);
  query.whereEqualTo(WebPackSubFileFields.path, filePath);

  {
    final serverFile = await query.first();
    if (serverFile != null) {
      await serverFile.delete();
    }
  }

  final techFileName = '${DateTime.now().millisecondsSinceEpoch}.data';

  final serverFileContent = ParseWebFile(fileContent, name : techFileName);
  await serverFileContent.save();

  final serverFile = ParseObject(WebPackSubFileFields.className);
  serverFile.set<ParseWebFile>(WebPackSubFileFields.file, serverFileContent);
  serverFile.set<String>(WebPackSubFileFields.path, filePath);
  serverFile.set<int>(WebPackSubFileFields.packId, packId);
  await serverFile.save();

  return serverFileContent.url!;
}

Future<void> deleteFileFromPack(int packId, String filePath) async {
  final query = QueryBuilder<ParseObject>(ParseObject(WebPackSubFileFields.className));
  query.whereEqualTo(WebPackFields.packId, packId);
  query.whereEqualTo(WebPackSubFileFields.path, filePath);

  final serverFile = await query.first();
  if (serverFile != null) {
    await serverFile.delete();
  }
}

Future<String?> moveFileInsidePack(int packId, String oldFilePath, String newFilePath, String oldUrl) async {
  final query = QueryBuilder<ParseObject>(ParseObject(WebPackSubFileFields.className));
  query.whereEqualTo(WebPackFields.packId, packId);
  query.whereEqualTo(WebPackSubFileFields.path, oldFilePath);

  final serverFile = await query.first();
  if (serverFile == null) return null;

  serverFile.set<String>(WebPackSubFileFields.path, newFilePath);
  await serverFile.save();

  return oldUrl;
}