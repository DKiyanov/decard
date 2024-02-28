import 'dart:io';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:flutter_archive/flutter_archive.dart';

import 'common_func.dart';
import 'db.dart';
import 'decardj.dart';
import 'parse_class_info.dart';
import 'loader.dart';
import 'local_pack_load.dart';

const String textUrlPrefix = 'text:';

//text URL format: text:<packId>|<path>
String buildTextUrl(int packId, String path) {
  return '$textUrlPrefix$packId|$path';
}

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
      packId        : parseObject.get<int>(ParseWebPackHead.packId  )!,
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
      publicationMoment: parseObject.get<DateTime>(ParseWebPackHead.publicationMoment),
      starsCount    : parseObject.get<int>(ParseWebPackHead.starsCount)??0,
      userID        : parseObject.get<String>(ParseWebPackHead.userID)!,
    );
  }

  Widget getListTile(BuildContext context, {Widget? leading, Widget? trailing, void Function(BuildContext context)? onTap}) {
    return ListTile(
      title    : getTitle(context),
      subtitle : getSubtitle(context),
      onTap    : ()=> onTap?.call(context),
      trailing : trailing,
      leading  : leading,
    );
  }

  Widget getTitle(BuildContext context) {
    return Text(title);
  }

  Widget getSubtitle(BuildContext context) {
    final subtitle = 'возраст: $targetAgeLow-$targetAgeHigh; ${tags.isEmpty ? 'теги отсутствуют' : 'теги: $tags'}; ${publicationMoment == null? 'не опубликовано' : 'опубликовано: ${dateToStr(publicationMoment!)}' }';
    return Text(subtitle);
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

class WebPackListManager {
  final _webPackInfoList = <WebPackInfo>[];
  bool _initialized = false;

  WebPackListManager();

  Future<void> init() async {
    if (_initialized) return;

    final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackHead.className));
    query.whereGreaterThan(ParseWebPackHead.publicationMoment, DateTime(2000));
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
      final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackUserFiles.className));
      query.whereEqualTo(ParseWebPackHead.userID, userID);
      final userPackList = await query.find();

      for (var userPack in userPackList) {
        final packId = userPack.get<int>(ParseWebPackHead.packId)!;
        final webPackInfo = _webPackInfoList.firstWhereOrNull((webPackInfo) => webPackInfo.packId == packId);
        if (webPackInfo == null) continue;

        result.add(webPackInfo);
      }
    }

    // own user packages
    final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackHead.className));
    query.whereEqualTo(ParseWebPackHead.userID, userID);
    final parsePackList = await query.find();

    for (var parsePack in parsePackList) {
      final packId = parsePack.get<int>(ParseWebPackHead.packId)!;
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

String getWebPackFileSourceID(int packId) {
  return 'WebPack:$packId';
}

Future<int?> loadWebPack(DbSource dbSource, int packId, {LoadPackAddInfoCallback? addInfoCallback, bool putFilesIntoLocalStore = false}) async {
  Map<String, String>? fileUrlMap;

  if (putFilesIntoLocalStore) {
    fileUrlMap = await _getPackSourceApp(packId);
  } else {
    fileUrlMap = await _getPackSourceWeb(packId);
  }

  if (fileUrlMap == null) return null;

  return await loadPack(dbSource, getWebPackFileSourceID(packId), fileUrlMap, addInfoCallback : addInfoCallback);
}

Future<Map<String, String>?> getPackSource(int packId, {bool putFilesIntoLocalStore = false}) async {
  if (putFilesIntoLocalStore) {
    return await _getPackSourceApp(packId);
  } else {
    return await _getPackSourceWeb(packId);
  }
}

Future<Map<String, String>?> _getPackSourceWeb(int packId) async {
  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackSubFile.className));
  query.whereEqualTo(ParseWebPackSubFile.packId, packId);
  query.keysToReturn([ParseWebPackSubFile.path, ParseWebPackSubFile.file, ParseWebPackSubFile.isText]);
  final sourceList = await query.find();

  final Map<String, String> fileUrlMap = {};

  for (var source in sourceList) {
    final path = source.get<String>(ParseWebPackSubFile.path)!;
    final isText = source.get<bool>(ParseWebPackSubFile.isText)??false;

    String url;

    if (isText) {
      url = buildTextUrl(packId, path);
    } else {
      if (kIsWeb) {
        url = source.get<ParseWebFile>(ParseWebPackSubFile.file)!.url!;
      } else {
        url = source.get<ParseFile>(ParseWebPackSubFile.file)!.url!;
      }
    }

    fileUrlMap[path] = url;
  }

  return fileUrlMap;
}

Future<String?> getTextFromParseTextUrl(String fileUrl) async {
  if (!fileUrl.startsWith(textUrlPrefix)) return null;
  final url = fileUrl.substring(textUrlPrefix.length);
  final parts = url.split('|');

  final packId = int.parse(parts.first);
  final path = parts.last;

  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackSubFile.className));
  query.whereEqualTo(ParseWebPackSubFile.packId, packId);
  query.whereEqualTo(ParseWebPackSubFile.path  , path);
  query.whereEqualTo(ParseWebPackSubFile.isText, true);
  query.keysToReturn([ParseWebPackSubFile.textContent]);
  final row = await query.first();

  if (row == null) return '';

  final text = row.get<String>(ParseWebPackSubFile.textContent)??'';
  return text;
}

class WebPackTextFile {
  final int packId;
  final String path;
  WebPackTextFile({required this.packId,required this.path});

  ParseObject? _parseObject;

  Future<void> _initParseObject() async {
    if (_parseObject != null) return;
    final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackSubFile.className));
    query.whereEqualTo(ParseWebPackSubFile.packId, packId);
    query.whereEqualTo(ParseWebPackSubFile.path  , path);
    query.whereEqualTo(ParseWebPackSubFile.isText, true);
    query.keysToReturn([ParseWebPackSubFile.textContent]);
    _parseObject = await query.first();
  }

  Future<String> getText() async {
    if (_parseObject == null) {
      await _initParseObject();
    }

    final result = _parseObject!.get<String>(ParseWebPackSubFile.textContent)??'';
    return result;
  }

  Future<void> setText(String newText) async {
    if (_parseObject == null) {
      await _initParseObject();
    }

    _parseObject!.set(ParseWebPackSubFile.textContent, newText);
    await _parseObject!.save();
  }
}

Future<Map<String, String>?> _getPackSourceApp(int packId) async {
  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackHead.className));
  query.whereEqualTo(ParseWebPackHead.packId, packId);
  query.keysToReturn([ParseWebPackHead.fileName, ParseWebPackHead.content]);
  final packInfo = await query.first();

  if (packInfo == null) return null;

  final packFileName = packInfo.get<String>(ParseWebPackHead.fileName)!;
  final fileExt = path_util.extension(packFileName).toLowerCase();
  if (!DjfFileExtension.values.contains(fileExt)) {
    return null;
  }

  Directory appDocDir = await getApplicationDocumentsDirectory();
  final packPath = path_util.join(appDocDir.path, 'pack_$packId');

  final dir = Directory(packPath);

  if (!dir.existsSync()) {
    final content = packInfo.get<ParseFile>(ParseWebPackHead.content)!;
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

Future<String> addTextFileToPack(int packId, String filePath, String fileContent) async {
  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackSubFile.className));
  query.whereEqualTo(ParseWebPackSubFile.packId, packId);
  query.whereEqualTo(ParseWebPackSubFile.path, filePath);

  final serverFile = await query.first();
  if (serverFile != null) {
    serverFile.set<String>(ParseWebPackSubFile.textContent, fileContent);
    await serverFile.save();
    return buildTextUrl(packId, filePath);
  }

  final newServerFile = ParseObject(ParseWebPackSubFile.className);
  newServerFile.set<bool>(ParseWebPackSubFile.isText, true);
  newServerFile.set<String>(ParseWebPackSubFile.textContent, fileContent);
  newServerFile.set<String>(ParseWebPackSubFile.path, filePath);
  newServerFile.set<int>(ParseWebPackSubFile.packId, packId);
  await newServerFile.save();
  return buildTextUrl(packId, filePath);
}

Future<String> addFileToPack(int packId, String filePath, Uint8List fileContent) async {
  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackSubFile.className));
  query.whereEqualTo(ParseWebPackSubFile.packId, packId);
  query.whereEqualTo(ParseWebPackSubFile.path, filePath);

  {
    final serverFile = await query.first();
    if (serverFile != null) {
      await serverFile.delete();
    }
  }

  final techFileName = '${DateTime.now().millisecondsSinceEpoch}.data';

  final serverFileContent = ParseWebFile(fileContent, name : techFileName);
  await serverFileContent.save();

  final serverFile = ParseObject(ParseWebPackSubFile.className);
  serverFile.set<ParseWebFile>(ParseWebPackSubFile.file, serverFileContent);
  serverFile.set<String>(ParseWebPackSubFile.path, filePath);
  serverFile.set<int>(ParseWebPackSubFile.packId, packId);
  await serverFile.save();

  return serverFileContent.url!;
}

Future<void> deleteFileFromPack(int packId, String filePath) async {
  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackSubFile.className));
  query.whereEqualTo(ParseWebPackHead.packId, packId);
  query.whereEqualTo(ParseWebPackSubFile.path, filePath);

  final serverFile = await query.first();
  if (serverFile != null) {
    await serverFile.delete();
  }
}

Future<String?> moveFileInsidePack(int packId, String oldFilePath, String newFilePath, String oldUrl) async {
  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackSubFile.className));
  query.whereEqualTo(ParseWebPackHead.packId, packId);
  query.whereEqualTo(ParseWebPackSubFile.path, oldFilePath);

  final serverFile = await query.first();
  if (serverFile == null) return null;

  serverFile.set<String>(ParseWebPackSubFile.path, newFilePath);
  await serverFile.save();

  return oldUrl;
}

Future<bool> addPackForChild(int packId, String userID, String sourcePath) async {
  final querySource = QueryBuilder<ParseObject>(ParseObject(ParseWebChildSource.className));
  querySource.whereEqualTo(ParseWebChildSource.userID, userID);
  querySource.whereEqualTo(ParseWebChildSource.path, sourcePath);
  querySource.whereEqualTo(ParseWebChildSource.sourceType, ParseWebChildSource.sourceTypePack);
  querySource.whereEqualTo(ParseWebChildSource.addInfo, '$packId');
  final source = await querySource.first();
  if (source != null) return false;

  final queryHead = QueryBuilder<ParseObject>(ParseObject(ParseWebPackHead.className));
  queryHead.whereEqualTo(ParseWebPackHead.packId, packId);
  queryHead.keysToReturn([ParseWebPackHead.content, ParseWebPackHead.fileName, ParseWebPackHead.fileSize]);
  final packHeadRow = (await queryHead.first())!;

  ParseFileBase content;
  if (kIsWeb) {
    content = packHeadRow.get<ParseWebFile>(ParseWebPackHead.content)!;
  } else {
    content = packHeadRow.get<ParseFile>(ParseWebPackHead.content)!;
  }

  final fileName = packHeadRow.get<String>(ParseWebPackHead.fileName)!;
  final fileSize = packHeadRow.get<int>(ParseWebPackHead.fileSize)!;

  final newSource = ParseObject(ParseWebChildSource.className);
  newSource.set(ParseWebChildSource.userID     , userID);
  newSource.set(ParseWebChildSource.path       , sourcePath);
  newSource.set(ParseWebChildSource.sourceType , ParseWebChildSource.sourceTypePack);
  newSource.set(ParseWebChildSource.addInfo    , '$packId');
  newSource.set(ParseWebChildSource.content    , content);
  newSource.set(ParseWebChildSource.fileName   , fileName);
  newSource.set(ParseWebChildSource.size       , fileSize);
  await newSource.save();
  return true;
}

Future<int?> getPackIdByGuid({required String fileGuid, required int fileVersion}) async {
  final query = QueryBuilder<ParseObject>(ParseObject(ParseWebPackHead.className));
  query.whereEqualTo(DjfFile.guid    , fileGuid);
  query.whereEqualTo(DjfFile.version , fileVersion);
  query.keysToReturn([ParseWebPackHead.packId]);
  final packInfo = await query.first();
  if (packInfo == null) return null;
  final packId = packInfo.get<int>(ParseWebPackHead.packId);
  return packId;
}