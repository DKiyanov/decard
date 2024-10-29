import 'dart:io';

import 'package:collection/collection.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as path_util;

import 'child.dart';
import 'common_func.dart';
import 'db.dart';
import 'parse_class_info.dart';
import 'platform_service.dart';

class ServerFunctions {
  final Map<String, String> _childName2IdMap = {};

  final String serverURL;
  final String userID;
  ServerFunctions(this.serverURL, this.userID);

  Future<String> _getChildID(String childName) async {
    var result = _childName2IdMap[childName];
    if (result != null) {
      return result;
    }

    final query =  QueryBuilder<ParseObject>(ParseObject(ParseChild.className));
    query.whereEqualTo(ParseChild.userID, userID);
    query.whereEqualTo(ParseChild.name, childName);

    final child = await query.first();
    result = child!.objectId!;

    _childName2IdMap[childName] = result;

    return result;
  }

  /// returns childName and deviceName associated with the device ID
  /// Server -> Child
  Future<ChildAndDeviceNames?> getChildDeviceFromDeviceID() async {
    final deviceID = await PlatformService.getDeviceID();

    final query =  QueryBuilder<ParseObject>(ParseObject(ParseDevice.className));
    query.whereEqualTo(ParseDevice.userID, userID);
    query.whereEqualTo(ParseDevice.deviceOSID, deviceID);
    final device = await query.first();
    if (device == null) return null;

    final childID = device.get<String>(ParseDevice.childID)!;

    final query2 =  QueryBuilder<ParseObject>(ParseObject(ParseChild.className));
    query2.whereEqualTo(ParseObjectField.objectID, childID);


    final child = (await query2.first())!;

    return ChildAndDeviceNames(child.get<String>(ParseChild.name)!, device.get<String>(ParseDevice.name)!);
  }

  /// Returns a list of children and devices associated with the child
  /// Server -> Client
  /// Future<Map<Child.name, List<Device.name>>>
  Future<Map<String, List<String>>> getChildDeviceMap() async {
    final Map<String, List<String>> result = {};

    final query =  QueryBuilder<ParseObject>(ParseObject(ParseChild.className));
    query.whereEqualTo(ParseChild.userID, userID);

    final childList = await query.find();
    for (var child in childList) {
      final childName = child.get<String>(ParseChild.name)!;

      final query =  QueryBuilder<ParseObject>(ParseObject(ParseDevice.className));
      query.whereEqualTo(ParseDevice.childID, child.objectId);

      final deviceList = await query.find();

      result[childName] = deviceList.map<String>((device) => device.get<String>(ParseDevice.name)!).toList();
    }

    return result;
  }

  /// Adds a new child - device
  /// Child -> Server
  /// returns the names of the created child/device in the structure
  Future<ChildAndDeviceNames> addChildDevice(String newChildName, String newDeviceName) async {
    final query =  QueryBuilder<ParseObject>(ParseObject(ParseChild.className));
    query.whereEqualTo(ParseChild.userID, userID);

    final childList = await query.find();

    var child = childList.firstWhereOrNull((child) => child.get<String>(ParseChild.name)!.toLowerCase() == newChildName.toLowerCase());

    if (child != null) {
      final query =  QueryBuilder<ParseObject>(ParseObject(ParseDevice.className));
      query.whereEqualTo(ParseDevice.childID, child.objectId);

      final deviceList = await query.find();
      final device = deviceList.firstWhereOrNull((device) => device.get<String>(ParseDevice.name)!.toLowerCase() == newDeviceName.toLowerCase());

      if (device != null) {
        return ChildAndDeviceNames(child.get<String>(ParseChild.name)!, device.get<String>(ParseDevice.name)!);
      }
    }

    if (child == null) {
      child = ParseObject(ParseChild.className);
      child.set<String>(ParseChild.userID, userID);
      child.set<String>(ParseChild.name  , newChildName);
      await child.save();
    }

    final deviceID = await PlatformService.getDeviceID();

    final device = ParseObject(ParseDevice.className);
    device.set<String>(ParseDevice.userID    , userID);
    device.set<String>(ParseDevice.childID   , child.objectId!);
    device.set<String>(ParseDevice.name      , newDeviceName);
    device.set<String>(ParseDevice.deviceOSID, deviceID);
    await device.save();

    return ChildAndDeviceNames(child.get<String>(ParseChild.name)!, device.get<String>(ParseDevice.name)!);
  }

  /// Synchronizes the contents of the child's directories on the server and on the device
  /// Server -> Child
  /// missing directories, on server or device - NOT created
  /// returns a list of updated/added files
  Future<List<String>> synchronizeChild(Child child) async {
    var netPath = path_util.join(child.name, child.deviceName);

    final query =  QueryBuilder<ParseObject>(ParseObject(ParseWebChildSource.className));
    query.whereEqualTo(ParseWebChildSource.userID, userID);
    query.whereContainedIn(ParseWebChildSource.path, [child.name, child.name]);

    final fileList = await query.find();

    final newFileList = <String>[];

    for (var file in fileList) {

      final fileName = file.get<String>(ParseWebChildSource.fileName)!;
      final fileTime = file.updatedAt!;
      final fileSize = file.get<int>(ParseWebChildSource.size)!;

      final netFilePath = path_util.join(serverURL, netPath, fileName);

      if (!await child.dbSource.tabSourceFile.checkFileRegistered(netFilePath, fileTime, fileSize)) {
        final filePath = path_util.join(child.downloadDir, fileName);
        final localFile = File(filePath);
        if (localFile.existsSync()) localFile.deleteSync();

        final content = file.get<ParseFile>(ParseWebChildSource.content);
        if (content != null) {
          await content.loadStorage();
          if ( content.file == null){
            await content.download();
          }

          await content.file!.copy(filePath);
        } else {
          final textContent = file.get<String>(ParseWebChildSource.textContent)!;
          await File(filePath).writeAsString(textContent);
        }

        await child.dbSource.tabSourceFile.registerFile(netFilePath, fileTime, fileSize);

        newFileList.add(fileName);
      }
    }

    return newFileList;
  }

  void _setFromJson(ParseObject object, Map<String, dynamic> json) {
    for (var key in json.keys) {
      object.set(key, json[key]);
    }
  }

  /// saves tests results
  /// child -> server
  Future<void> saveTestsResults(Child child) async {
    final resultList = child.cardResultList;
    if (resultList.isEmpty) return;

    final childID = await _getChildID(child.name);

    for (var row in resultList) {
      final json = row.toJson();

      final testResult = ParseObject(ParseTestResult.className);
      _setFromJson(testResult, json);
      testResult.set<String>(ParseTestResult.userID , userID);
      testResult.set<String>(ParseTestResult.childID, childID);

      testResult.save();
    }

    resultList.clear();
  }

  /// Returns test results for a period
  /// server -> manager
  Future<List<TestResult>> getTestsResultsFromServer(Child child, int from, int to) async {
    final result = <TestResult>[];

    final childID = await _getChildID(child.name);

    final query =  QueryBuilder<ParseObject>(ParseObject(ParseTestResult.className));
    query.whereEqualTo(ParseTestResult.userID, userID);
    query.whereEqualTo(ParseTestResult.childID, childID);
    query.whereGreaterThanOrEqualsTo(ParseTestResult.dateTime, from);
    query.whereLessThanOrEqualTo(ParseTestResult.dateTime, to);

    final resultList = await query.find();

    for (var row in resultList) {
      final json = row.toJson();
      final testResult = TestResult.fromMap(json);
      result.add(testResult);
    }

    return result;
  }

  /// saves statistics
  /// data from table stat
  /// child -> server
  Future<void> saveStatToServer(Child child) async {
    final childID = await _getChildID(child.name);

    final query =  QueryBuilder<ParseObject>(ParseObject(ParseDecardStat.className));
    query.whereEqualTo(ParseDecardStat.userID, userID);
    query.whereEqualTo(ParseDecardStat.childID, childID);

    final statList = await query.find();

    final rows = await child.dbSource.tabCardStat.getAllRows();

    CardStatExchange.dbSource = child.dbSource;

    for (var row in rows) {
      final cse = CardStatExchange.fromDbMap(row);

      var stat = statList.firstWhereOrNull((stat) => stat.get(ParseDecardStat.fileGuid)! == cse.fileGuid && stat.get(ParseDecardStat.cardID)! == cse.cardID );
      if (stat == null) {
        stat = ParseObject(ParseDecardStat.className);
        stat.set<String>(ParseDecardStat.userID, userID);
        stat.set<String>(ParseDecardStat.userID, childID);
      }

      final json = cse.toJson();
      _setFromJson(stat, json);
      stat.save();
    }

  }

  /// load statistics
  /// update data in table stat
  /// server -> client
  Future<int> updateStatFromServer(Child child, int lastStatDate) async {
    final childID = await _getChildID(child.name);

    final query =  QueryBuilder<ParseObject>(ParseObject(ParseDecardStat.className));
    query.whereEqualTo(ParseDecardStat.userID, userID);
    query.whereEqualTo(ParseDecardStat.childID, childID);

    final statList = await query.find();
    if (statList.isEmpty) return 0;

    DateTime? lastUpdateDate;
    for (var stat in statList) {
      if (lastUpdateDate == null || stat.updatedAt!.compareTo(lastUpdateDate) > 0 ){
        lastUpdateDate = stat.updatedAt;
      }
    }

    final lastUpdateIntDate = dateToInt(lastUpdateDate!);
    if (lastStatDate >= lastUpdateIntDate) return 0;

    CardStatExchange.dbSource = child.dbSource;

    for (var stat in statList) {
      final json = stat.toJson();

      final statExchange = CardStatExchange.fromJson(json);
      final dbRowMap = await statExchange.toDbMap();
      if (dbRowMap.isEmpty) continue;

      final int jsonFileID = dbRowMap[TabCardStat.kJsonFileID];
      final int cardID     = dbRowMap[TabCardStat.kCardID];

      final updateOk = await child.dbSource.tabCardStat.updateRow(jsonFileID, cardID, dbRowMap);
      if (!updateOk) {
        child.dbSource.tabCardStat.insertRowFromMap(dbRowMap);
      }
    }

    return lastUpdateIntDate;
  }

}
