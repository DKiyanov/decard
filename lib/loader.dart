import 'dart:convert';
import 'package:path/path.dart' as path_util;

import 'card_model.dart';
import 'db.dart';
import 'decardj.dart';
import 'media_widgets.dart';

enum DecardFileType {
  json,
  zip,
  notDecardFile
}

DecardFileType getDecardFileType(String fileName){
  final fileExt = path_util.extension(fileName).toLowerCase();
  if (fileExt == DjfFileExtension.json) return DecardFileType.json;
  if (fileExt == DjfFileExtension.zip) return DecardFileType.zip;
  return DecardFileType.notDecardFile;
}

typedef LoadPackAddInfoCallback = Function(String jsonStr, String jsonPath, String rootPath, Map<String, String> fileUrlMap);

Future<int?> loadPack(DbSource dbSource, String sourceFileID, Map<String, String> fileUrlMap, {bool onlyLastVersion = false, bool reInitDB = true, LoadPackAddInfoCallback? addInfoCallback}) async {
  String? jsonUrl;
  late String jsonPath;

  for (var fileUrlMapEntry in fileUrlMap.entries) {
    if (fileUrlMapEntry.key.toLowerCase().endsWith(DjfFileExtension.json)) {
      jsonPath = fileUrlMapEntry.key;
      jsonUrl  = fileUrlMapEntry.value;
      break;
    }
  }

  if (jsonUrl == null) return null;

  fileUrlMap.remove(jsonPath);
  final rootPath = path_util.dirname(jsonPath);

  final fileUrlMapOk = <String, String>{};

  for (var fileUrlMapEntry in fileUrlMap.entries) {
    final newPath = path_util.relative(fileUrlMapEntry.key, from: rootPath);
    fileUrlMapOk[newPath] = fileUrlMapEntry.value;
  }

  final jsonStr = await getTextFromUrl(jsonUrl);

  if (jsonStr == null) return null;

  final jsonMap = jsonDecode(jsonStr);

  final jsonFileID = await dbSource.loadJson(sourceFileID: sourceFileID, rootPath: rootPath, jsonMap: jsonMap, fileUrlMap: fileUrlMapOk);

  if (jsonFileID == null) return null;

  if (addInfoCallback != null) {
    addInfoCallback.call(jsonStr, jsonPath, rootPath, fileUrlMapOk);
  }

  return jsonFileID;
}

class DataLoader {
  final errorList = <String>[];

  final DbSource dbSource;

  DataLoader(this.dbSource);

  Future<int?> loadJson(String sourceFileID, String rootPath, Map<String, dynamic> jsonMap, [bool onlyLastVersion = false]) async {

    final jsonFileRow = await dbSource.tabJsonFile.getRowBySourceID(sourceFileID: sourceFileID);
    if (jsonFileRow != null) {
      return jsonFileRow[TabJsonFile.kJsonFileID];
    }

    final String guid = jsonMap[TabJsonFile.kGuid]??'';
    if (guid.isEmpty) {
      errorList.add('filed ${TabJsonFile.kGuid} not found');
      return null;
    }

    final int fileVersion = jsonMap[TabJsonFile.kVersion]??0;

    bool isNew = true;

    if (onlyLastVersion) {
      final rows = await dbSource.tabJsonFile.getRowByGuid(guid);

      for (var row in rows) {
        final rowVersion = (row[TabJsonFile.kVersion]??0) as int;
        if (fileVersion <= rowVersion) return null;

        isNew = false;

        final rowJsonFileID = row[TabJsonFile.kJsonFileID] as int;
        clearJsonFileID(rowJsonFileID);
      }
    }

    final jsonFileID = await dbSource.tabJsonFile.insertRow(sourceFileID, rootPath, jsonMap);

    final styleList = (jsonMap[DjfFile.cardStyleList]??[]) as List;
    for (Map<String, dynamic> cardStyle in styleList) {
      await dbSource.tabCardStyle.insertRow(
        jsonFileID   : jsonFileID,
        cardStyleKey : cardStyle[DjfCardStyle.id],
        jsonStr      : jsonEncode(cardStyle)
      );
    }

    final qualityLevelList = (jsonMap[DjfFile.qualityLevelList]??[]) as List;
    for (Map<String, dynamic> qualityLevel in qualityLevelList) {
      await dbSource.tabQualityLevel.insertRow(
          jsonFileID   : jsonFileID,
          qualityName  : qualityLevel[DjfQualityLevel.qualityName],
          minQuality   : qualityLevel[DjfQualityLevel.minQuality],
          avgQuality   : qualityLevel[DjfQualityLevel.avgQuality],
      );
    }

    final cardKeyList = <String>[];

    final templateList = (jsonMap[DjfFile.templateList]??[]) as List;
    final templatesSources = (jsonMap[DjfFile.templatesSources]??[]) as List;
    if (templateList.isNotEmpty && templatesSources.isNotEmpty) {
      await _processTemplateList(jsonFileID: jsonFileID, templateList : templateList, sourceList: templatesSources, cardKeyList : cardKeyList);
    }

    final cardList = (jsonMap[DjfFile.cardList]??[]) as List?;
    if (cardList != null) {
      await _processCardList(jsonFileID: jsonFileID, cardList : cardList, cardKeyList : cardKeyList);
    }

    if (!isNew){
      await dbSource.tabCardStat.removeOldCard(jsonFileID, cardKeyList);
    }

    return jsonFileID;
  }

  Future<void> _processTemplateList({required int jsonFileID, required List templateList, required List sourceList, required List<String> cardKeyList}) async {
    for(int templateListIndex = 0; templateListIndex < templateList.length; templateListIndex ++) {
      final template = templateList[templateListIndex];

      final templateName          = template[DjfCardTemplate.templateName] as String;
      final cardTemplateList      = template[DjfCardTemplate.cardTemplateList];
      final cardsTemplatesJsonStr = jsonEncode(cardTemplateList);

      for( int sourceListIndex = 0; sourceListIndex < sourceList.length; sourceListIndex ++) {
        final sourceRow = sourceList[sourceListIndex] as Map<String, dynamic>;

        if (sourceRow[DjfTemplateSource.templateName] == templateName) {

          final sourceRowId = await dbSource.tabTemplateSource.insertRow(jsonFileID: jsonFileID, source: sourceRow);

          String curTemplate = cardsTemplatesJsonStr;

          sourceRow.forEach((key, value) {
            curTemplate =  curTemplate.replaceAll('${DjfTemplateSource.paramBegin}$key${DjfTemplateSource.paramEnd}', value);
          });

          final cardList = jsonDecode(curTemplate) as List;
          await _processCardList(jsonFileID: jsonFileID, cardList : cardList, cardKeyList : cardKeyList, templateIndex: templateListIndex, sourceIndex: sourceListIndex, sourceRowId: sourceRowId);
        }
      }
    }
  }

  Future<void> _processCardList({required int jsonFileID, required List cardList, required List<String> cardKeyList, int? templateIndex, int? sourceIndex, int? sourceRowId}) async {
    for(int cardLisIndex = 0; cardLisIndex < cardList.length; cardLisIndex ++) {
      final card = cardList[cardLisIndex] as Map<String, dynamic>;

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
        help         : card[DjfCard.help]??'',
        difficulty   : card[DjfCard.difficulty]??0,
        cardGroupKey : groupKey,
        bodyCount    : bodyList.length,
        cardListIndex: cardLisIndex,
        templateIndex: templateIndex,
        sourceIndex  : sourceIndex,
        sourceRowId  : sourceRowId,
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

    for (int linkListIndex = 0; linkListIndex < linkList.length; linkListIndex ++) {
      final link = linkList[linkListIndex];

      final linkID = await dbSource.tabCardLink.insertRow(
        jsonFileID  : jsonFileID,
        cardID      : cardID,
        qualityName : link[DjfUpLink.qualityName],
        linkIndex   :  linkListIndex,
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
      dbSource.tabCardBody.insertRow(
        jsonFileID : jsonFileID,
        cardID     : cardID,
        bodyNum    : bodyNum,
        json       : jsonEncode(body)
      );
      bodyNum++;
    }
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

  Future<void> clearJsonFileID(int jsonFileID) async {
    await dbSource.tabCardStyle.deleteJsonFile(jsonFileID);
    await dbSource.tabCardHead.deleteJsonFile(jsonFileID);
    await dbSource.tabCardBody.deleteJsonFile(jsonFileID);
    await dbSource.tabCardTag.deleteJsonFile(jsonFileID);
    await dbSource.tabCardLink.deleteJsonFile(jsonFileID);
    await dbSource.tabCardLinkTag.deleteJsonFile(jsonFileID);
    await dbSource.tabQualityLevel.deleteJsonFile(jsonFileID);
    await dbSource.tabTemplateSource.deleteJsonFile(jsonFileID);
    await dbSource.tabFileUrlMap.deleteJsonFile(jsonFileID);
  }
}

class DbValidatorResult {
  final String path;
  final String message;
  final int?   sourceIndex;

  DbValidatorResult(this.path, this.message, this.sourceIndex);
}

// pack json file validator
class DbValidator {
  DbSource dbSource;
  int _jsonFileID = 0;

  DbValidator(this.dbSource);


  Future<List<DbValidatorResult>> checkJsonFile(int jsonFileID) async {
    _jsonFileID = jsonFileID;

    final result = <DbValidatorResult>[];

    final tagList       = await dbSource.tabCardTag.getFileTagList(jsonFileID: jsonFileID);
    final cardKeyList   = await dbSource.tabCardHead.getFileCardKeyList(jsonFileID: jsonFileID);
    final cardGroupList = await dbSource.tabCardHead.getFileGroupList(jsonFileID: jsonFileID);
    final qualityList   = await dbSource.tabQualityLevel.getLevelNameList(jsonFileID: jsonFileID);

    final linkTagRowList = await dbSource.tabCardLinkTag.getFileRowList(jsonFileID: jsonFileID);
    final linkHeadRowList = await dbSource.tabCardLink.getFileRowList(jsonFileID: jsonFileID);

    for (var linkRow in linkTagRowList) {
      final linkTag = linkRow[TabCardLinkTag.kTag] as String;
      String? fieldName;
      String? message;

      // card upLink cards
      if (linkTag.startsWith(DjfUpLink.cardTagPrefix)) {
        final cardKey = linkTag.substring(DjfUpLink.cardTagPrefix.length);
        if (cardKeyList.contains(cardKey)) continue;
        fieldName = DjfUpLink.cards;
        message = 'Нет карточки с идентификатором "$cardKey" в пакете';
      }

      // card upLink groups
      if (linkTag.startsWith(DjfUpLink.groupTagPrefix)) {
        final cardGroup = linkTag.substring(DjfUpLink.groupTagPrefix.length);
        if (cardGroupList.contains(cardGroup)) continue;
        fieldName = DjfUpLink.groups;
        message = 'Нет группы карточек "$cardGroup" в пакете';
      }

      // card upLink tags
      if (tagList.contains(linkTag)) continue;

      fieldName ??= DjfUpLink.tags;
      message   ??= 'Нет карточек с тегом "$linkTag" в пакете';

      final linkID = linkRow[TabCardLinkTag.kLinkID] as int;

      final linkHeadRow = linkHeadRowList.firstWhere((headRow) => (headRow[TabCardLink.kLinkID] as int) == linkID);
      final cardID      = linkHeadRow[TabCardLink.kCardID   ] as int;
      final linkIndex   = linkHeadRow[TabCardLink.kLinkIndex] as int;

      final subPath = '${DjfCard.upLinks}[$linkIndex]/$fieldName';

      result.add(await getCardResult(cardID, subPath, message));
    }

    // card upLink quality level
    for (var linkHeadRow in linkHeadRowList) {
      final qualityName = linkHeadRow[TabCardLink.kQualityName] as String;
      if (qualityList.contains(qualityName)) continue;

      final cardID    = linkHeadRow[TabCardLink.kCardID   ] as int;
      final linkIndex = linkHeadRow[TabCardLink.kLinkIndex] as int;
      final subPath = '${DjfCard.upLinks}[$linkIndex]/${DjfUpLink.qualityName}';
      final message = 'Нет уровня качества "$qualityName" в пакете';

      result.add(await getCardResult(cardID, subPath, message));
    }

    final styleKeyList = await dbSource.tabCardStyle.getStyleKeyList(jsonFileID: jsonFileID);

    final bodyKeyList = await dbSource.tabCardBody.getFileKeyList(jsonFileID: jsonFileID);
    for (var bodyKey in bodyKeyList) {
      final bodyRow = (await dbSource.tabCardBody.getRow(jsonFileID: jsonFileID, cardID:  bodyKey.cardID, bodyNum: bodyKey.bodyNum))!;

      // body styleIdList
      final bodyStyleKeyList = (bodyRow[DjfCardBody.styleIdList]??[]) as List;
      for (var row in bodyStyleKeyList) {
        final styleKey = row as String;
        if (styleKeyList.contains(styleKey)) continue;

        final subPath = '${DjfCard.bodyList}[${bodyKey.bodyNum}]/${DjfCardBody.styleIdList}';
        final message = 'Нет стиля "$styleKey" в пакете';

        result.add(await getCardResult(bodyKey.cardID, subPath, message));
      }

      // body questionData pack file source
      final questionDataList = (bodyRow[DjfCardBody.questionData]??[]) as List;
      for (var row in questionDataList) {
        final source = CardSource(row as String);
        if (!source.isPackFile) continue;
        final fileUrl = dbSource.getFileUrl(jsonFileID, source.data);
        if (fileUrl != null) continue;

        final subPath = '${DjfCard.bodyList}[${bodyKey.bodyNum}]/${DjfCardBody.questionData}';
        final message = 'Файла "${source.data}" в пакете нет';

        result.add(await getCardResult(bodyKey.cardID, subPath, message));
      }

    }

    return result;
  }

  Future<DbValidatorResult> getCardResult(int cardID, subPath, message) async {
    final row = (await dbSource.tabCardHead.getRow(jsonFileID: _jsonFileID, cardID: cardID))!;

    final cardListIndex = row[TabCardHead.kCardListIndex] as int;
    final templateIndex = row[TabCardHead.kTemplateIndex] as int?;
    final sourceIndex   = row[TabCardHead.kSourceIndex  ] as int?;

    String path;
    if (templateIndex != null) {
      path = '${DjfFile.templateList}[$templateIndex]/${DjfCardTemplate.cardTemplateList}[$cardListIndex]';
    } else {
      path = '${DjfFile.cardList}[$cardListIndex]';
    }

    return DbValidatorResult('$path/$subPath', message, sourceIndex);
  }
}


