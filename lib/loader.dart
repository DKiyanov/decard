import 'dart:convert';
import 'dart:io';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:path/path.dart' as path_util;

import 'db.dart';
import 'decardj.dart';

enum DecardFileType {
  json,
  zip,
  notDecardFile
}

DecardFileType getDecardFileType(String fileName){
  final fileExt = path_util.extension(fileName).toLowerCase();
  if (fileExt == '.decardj') return DecardFileType.json;
  if (fileExt == '.decardz') return DecardFileType.zip;
  return DecardFileType.notDecardFile;
}

class DataLoader {
  String _selfDir = '';
  int _dirIndex = 0;
  final errorList = <String>[];

  int _lastSourceFileID = 0;

  static const String _subDirPrefix    = 'j'; // subdirectory name prefix

  DbSource? _dbSource;
  DbSource get dbSource => _dbSource!;

  Map<String, dynamic>? _templateSourceRow;
  int _templateSourceRowIndex = 0;
  String? _jsonPath;

  DataLoader();
  

  /// Scans the list of directories and selects files with extensions: '.decardz', '.decardj'
  /// The '.decardz' files are unpacked into subdirectories, prefix for subdirectories [_subDirPrefix]
  /// The '.decardj' data is stored in the database
  /// version control is performed compared to what was previously loaded into the database
  Future<void> refreshDB({ required List<String> dirForScanList, required String selfDir, required DbSource dbSource}) async {
    _selfDir = selfDir;
    _dbSource = dbSource;
    errorList.clear();

    for (var dir in dirForScanList) {
      _scanDir(dir, regFiles : true);
    }
  }

  Future<bool> _scanDir(String dir, {bool regFiles = false}) async {
    bool result = false;

    // in API 33 problem with receive file list on external storage
    // need permission MANAGE_EXTERNAL_STORAGE
    // https://android-tools.ru/coding/poluchaem-razreshenie-manage_external_storage-dlya-prilozheniya/
    final fileList = Directory(dir).listSync( recursive: true);

    for (var object in fileList) {
      if (object is File){
        final File file = object;
        final fileType = getDecardFileType(file.path);

        if (fileType == DecardFileType.zip) {
          if (await _checkFileIsNoRegistered(file)) {
            if (regFiles) await _registerFile(file);
            if (await _processZip(file)) {
              result = true;
            }
          }
        }

        if (fileType == DecardFileType.json) {
          if (await _checkFileIsNoRegistered(file)) {
            if (regFiles) await _registerFile(file);
            if (await _processJson(file)) {
              result = true;
            }
          }
        }

      }
    }

    return result;
  }

  Future<void> _registerFile(File file) async {
    _lastSourceFileID = await dbSource.tabSourceFile.registerFile(file);
  }

  Future<bool> _checkFileIsNoRegistered(File file) async {
    return ! await dbSource.tabSourceFile.checkFileRegistered(file);
  }

  Future<bool> _processZip(File zipFile) async {
    bool result = false;

    Directory dir;
    do {
      _dirIndex ++;
      dir = Directory(path_util.join(_selfDir, '$_subDirPrefix$_dirIndex' ));
    } while (await dir.exists());
    await dir.create();

    try {
      await ZipFile.extractToDirectory(zipFile: zipFile, destinationDir: dir);
      result = await _scanDir(dir.path);
      if (!result){
        dir.delete(recursive: true);
      }
    } catch (e) {
      errorList.add(e.toString());
    }

    return result;
  }

  Future<bool> _processJson(File jsonFile) async {
    final fileData = await jsonFile.readAsString();
    final json = jsonDecode(fileData);

    final String guid = json[TabJsonFile.kGuid]??'';
    if (guid.isEmpty) {
      errorList.add('in file ${jsonFile.path} filed ${TabJsonFile.kGuid} not found');
      return false;
    }

    final int fileVersion = json[TabJsonFile.kVersion]??0;

    bool isNew = true;

    if (await dbSource.tabJsonFile.getRowByGuid(guid)) {
      if (fileVersion <= dbSource.tabJsonFile.version) return false;
      isNew = false;
      await _clearJsonFileID(dbSource.tabJsonFile.jsonFileID);
    }

    _jsonPath = path_util.dirname(jsonFile.path);
    dbSource.tabJsonFile.setRow(_lastSourceFileID, _jsonPath!, path_util.basename(jsonFile.path), json);
    await dbSource.tabJsonFile.save();

    final int jsonFileID = dbSource.tabJsonFile.jsonFileID;

    final styleList = (json[DjfFile.cardStyleList]) as List;
    for (Map<String, dynamic> cardStyle in styleList) {
      await dbSource.tabCardStyle.insertRow(
        jsonFileID   : jsonFileID,
        cardStyleKey : cardStyle[DjfCardStyle.id],
        jsonStr      : jsonEncode(cardStyle)
      );
    }

    final qualityLevelList = (json[DjfFile.qualityLevelList]) as List;
    for (Map<String, dynamic> qualityLevel in qualityLevelList) {
      await dbSource.tabQualityLevel.insertRow(
          jsonFileID   : jsonFileID,
          qualityName  : qualityLevel[DjfQualityLevel.qualityName],
          minQuality   : qualityLevel[DjfQualityLevel.minQuality],
          avgQuality   : qualityLevel[DjfQualityLevel.avgQuality],
      );
    }

    final cardKeyList = <String>[];

    final templateList = (json[DjfFile.templateList]) as List?;
    final templatesSources = (json[DjfFile.templatesSources]) as List?;
    if (templateList != null && templatesSources != null) {
      await _processTemplateList(jsonFileID: jsonFileID, templateList : templateList, sourceList: templatesSources, cardKeyList : cardKeyList);
    }

    final cardList = (json[DjfFile.cardList]) as List?;
    if (cardList != null) {
      await _processCardList(jsonFileID: jsonFileID, cardList : cardList, cardKeyList : cardKeyList);
    }

    if (!isNew){
      await dbSource.tabCardStat.removeOldCard(jsonFileID, cardKeyList);
    }

    return true;
  }

  Future<void> _processTemplateList({required int jsonFileID, required List templateList, required List sourceList, required List<String> cardKeyList}) async {
    for (var template in templateList) {
      final templateName          = template[DjfCardTemplate.templateName] as String;
      final cardTemplateList      = template[DjfCardTemplate.cardTemplateList];
      final cardsTemplatesJsonStr = jsonEncode(cardTemplateList);

      _templateSourceRowIndex = 0;

      for (Map<String, dynamic> sourceRow in sourceList) {
        if (sourceRow[DjfTemplateSource.templateName] == templateName) {

          String curTemplate = cardsTemplatesJsonStr;

          sourceRow.forEach((key, value) {
            curTemplate =  curTemplate.replaceAll('${DjfTemplateSource.paramBegin}$key${DjfTemplateSource.paramEnd}', value);
          });

          _templateSourceRow = sourceRow;
          _templateSourceRowIndex ++;

          final cardList = jsonDecode(curTemplate) as List;
          await _processCardList(jsonFileID: jsonFileID, cardList : cardList, cardKeyList : cardKeyList);

        }
      }
    }

    _templateSourceRow = null;
    _templateSourceRowIndex = 0;
  }

  Future<void> _prepareTemplateFile(String paramName, Map<String, dynamic> questionData) async {
    final fileName = (questionData[paramName]??'') as String;
    if (fileName.isEmpty) return;

    final filePath = path_util.normalize( path_util.join(_jsonPath!, fileName) );
    final file = File(filePath);
    String fileData = await file.readAsString();

    _templateSourceRow!.forEach((key, value) {
      fileData =  fileData.replaceAll('${DjfTemplateSource.paramBegin}$key${DjfTemplateSource.paramEnd}', value);
    });

    final path = path_util.dirname(filePath);
    final newFileName = 'tg$_templateSourceRowIndex-$fileName';
    final newFilePath = path_util.join(path, newFileName);
    final newFile = File(newFilePath);

    if (newFile.existsSync()) return;

    newFile.writeAsString(fileData);

    questionData[paramName] = newFileName;
  }

  Future<void> _processCardList({required int jsonFileID, required List cardList, required List<String> cardKeyList}) async {
    for (Map<String, dynamic> card in cardList) {
      final String cardKey = card[DjfCard.id];

      if (cardKey.isEmpty) continue; // the card must have a unique identifier within the file
      if (cardKeyList.contains(cardKey)) continue; // card identifiers must be unique

      cardKeyList.add(cardKey);

      final groupKey = card[DjfCard.group]??cardKey;

      final bodyList = (card[DjfCard.bodyList]) as List;

      final cardID = await dbSource.tabCardHead.insertRow(
        jsonFileID   : jsonFileID,
        cardKey      : cardKey,
        title        : card[DjfCard.title],
        difficulty   : card[DjfCard.difficulty]??0,
        cardGroupKey : groupKey,
        bodyCount    : bodyList.length,
      );

      await _processCardBodyList(
        jsonFileID : jsonFileID,
        cardID     : cardID,
        bodyList   : bodyList,
      );

      await _processCardTagList(
        jsonFileID : jsonFileID,
        cardID     : cardID,
        cardKey    : cardKey,
        groupKey   : groupKey,
        tagList    : card[DjfCard.tags] as List?,
      );

      await _processCardLinkList(
        jsonFileID : jsonFileID,
        cardID     : cardID,
        linkList   : card[DjfCard.upLinks] as List?,
      );

      await _intCardStat(
        jsonFileID : jsonFileID,
        cardID     : cardID,
        cardKey    : cardKey,
        groupKey   : groupKey,
      );
    }
  }

  Future<void> _processCardLinkList({ required int jsonFileID, required int cardID, required List? linkList }) async {
    if (linkList == null) return;

    for (var link in linkList) {
      final linkID = await dbSource.tabCardLink.insertRow(
          jsonFileID  : jsonFileID,
          cardID      : cardID,
          qualityName : link[DjfUpLink.qualityName],
      );

      await _processCardLinkTagList( jsonFileID: jsonFileID, linkID: linkID, tagList: link[DjfUpLink.tags  ] as List?);
      await _processCardLinkTagList( jsonFileID: jsonFileID, linkID: linkID, tagList: link[DjfUpLink.cards ] as List?, prefix: DjfUpLink.cardTagPrefix);
      await _processCardLinkTagList( jsonFileID: jsonFileID, linkID: linkID, tagList: link[DjfUpLink.groups] as List?, prefix: DjfUpLink.groupTagPrefix);
    }
  }

  Future<void> _processCardLinkTagList({ required int jsonFileID, required int linkID, String prefix = '', required List? tagList }) async {
    if (tagList == null) return;

    for (String tag in tagList) {
      dbSource.tabCardLinkTag.insertRow(jsonFileID: jsonFileID, linkId: linkID, tag: prefix + tag);
    }
  }

  Future<void> _processCardBodyList({ required int jsonFileID, required int cardID, required List bodyList }) async {
    int bodyNum = 0;
    for (var body in bodyList) {
      await _prepareBodyQuestionData(body);

      dbSource.tabCardBody.insertRow(
        jsonFileID : jsonFileID,
        cardID     : cardID,
        bodyNum    : bodyNum,
        json       : jsonEncode(body)
      );
      bodyNum++;
    }
  }

  Future<void> _prepareBodyQuestionData( Map<String, dynamic> cardBody) async {
    final questionData =  cardBody[DjfCardBody.questionData] as Map<String, dynamic>;

    await _prepareTemplateFile(DjfQuestionData.markdown, questionData);
    await _prepareTemplateFile(DjfQuestionData.html, questionData);
  }

  Future<void> _processCardTagList({ required int jsonFileID, required int cardID, required String cardKey, required String groupKey, required List? tagList }) async {
    if (tagList == null) return;

    dbSource.tabCardTag.insertRow(
      jsonFileID     : jsonFileID,
      cardID         : cardID,
      tag            : DjfUpLink.cardTagPrefix + cardKey,
    );

    if (groupKey.isNotEmpty) {
      dbSource.tabCardTag.insertRow(
        jsonFileID     : jsonFileID,
        cardID         : cardID,
        tag            : DjfUpLink.groupTagPrefix + groupKey,
      );
    }

    for (var tag in tagList) {
      dbSource.tabCardTag.insertRow(
        jsonFileID     : jsonFileID,
        cardID         : cardID,
        tag            : tag,
      );
    }
  }

  Future<void> _intCardStat({required int jsonFileID, required int cardID, required String cardKey, required String groupKey}) async {
    await dbSource.tabCardStat.insertRow(
      jsonFileID   : jsonFileID,
      cardID       : cardID,
      cardKey      : cardKey,
      cardGroupKey : groupKey,
    );
  }

  Future<void> _clearJsonFileID(int jsonFileID) async {
    await dbSource.tabCardStyle.deleteJsonFile(jsonFileID);
    await dbSource.tabCardHead.deleteJsonFile(jsonFileID);
    await dbSource.tabCardBody.deleteJsonFile(jsonFileID);
    await dbSource.tabCardTag.deleteJsonFile(jsonFileID);
    await dbSource.tabCardLink.deleteJsonFile(jsonFileID);
    await dbSource.tabCardLinkTag.deleteJsonFile(jsonFileID);
    await dbSource.tabQualityLevel.deleteJsonFile(jsonFileID);
  }
}
