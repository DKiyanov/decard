import 'dart:io';

import 'package:collection/collection.dart';
import 'package:decard/platform_service.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk.dart';
import 'package:path/path.dart' as path_util;

import 'child.dart';
import 'common.dart';
import 'db.dart';

class ServerFunctions {
  static const String _commonFolderName = "common_folder";

  static const String _clsChild      = 'Child';
  static const String _clsDevice     = 'Device';

  static const String _clsFile       = 'DecardFile';
  static const String _clsTestResult = 'DecardTestResult';
  static const String _clsStat       = 'DecardStat';

  static const String _fldObjectID   = 'objectId';
  static const String _fldUserID     = 'UserID';
  static const String _fldName       = 'Name';
  static const String _fldChildID    = 'ChildID';
  static const String _fldDeviceOSID = 'DeviceOSID';

  static const String _fldPath     = 'Path';
  static const String _fldFileName = 'FileName';
  static const String _fldSize     = 'Size';
  static const String _fldContent  = 'Content';

  static const String _fldDateTime = 'dateTime';

  static const String _fldFileGuid = 'FileGuid';
  static const String _fldCardID   = 'CardID';

  final Map<String, String> _childName2IdMap = {};

  final String serverURL;
  final String userID;
  ServerFunctions(this.serverURL, this.userID);

  Future<String> _getChildID(String childName) async {
    var result = _childName2IdMap[childName];
    if (result != null) {
      return result;
    }

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsChild));
    query.whereEqualTo(_fldUserID, userID);
    query.whereEqualTo(_fldName, childName);

    final child = await query.first();
    result = child!.objectId!;

    _childName2IdMap[childName] = result;

    return result;
  }

  /// returns childName and deviceName associated with the device ID
  /// Server -> Child
  Future<ChildAndDeviceNames?> getChildDeviceFromDeviceID() async {
    final deviceID = await PlatformService.getDeviceID();

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsDevice));
    query.whereEqualTo(_fldDeviceOSID, deviceID);
    final device = await query.first();
    if (device == null) return null;

    final childID = device.get<String>(_fldChildID)!;

    final query2 =  QueryBuilder<ParseObject>(ParseObject(_clsChild));
    query2.whereEqualTo(_fldObjectID, childID);


    final child = (await query2.first())!;

    return ChildAndDeviceNames(child.get<String>(_fldName)!, device.get<String>(_fldName)!);
  }

  /// Returns a list of children and devices associated with the child
  /// Server -> Client
  /// Future<Map<Child.name, List<Device.name>>>
  Future<Map<String, List<String>>> getChildDeviceMap() async {
    final Map<String, List<String>> result = {};

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsChild));
    query.whereEqualTo(_fldUserID, userID);

    final childList = await query.find();
    for (var child in childList) {
      final childName = child.get<String>(_fldName)!;

      final query =  QueryBuilder<ParseObject>(ParseObject(_clsDevice));
      query.whereEqualTo(_fldChildID, child.objectId);

      final deviceList = await query.find();

      result[childName] = deviceList.map<String>((device) => device.get<String>(_fldName)!).toList();
    }

    return result;
  }

  /// Adds a new child - device
  /// Child -> Server
  /// returns the names of the created child/device in the structure
  Future<ChildAndDeviceNames> addChildDevice(String newChildName, String newDeviceName) async {
    final query =  QueryBuilder<ParseObject>(ParseObject(_clsChild));
    query.whereEqualTo(_fldUserID, userID);

    final childList = await query.find();

    var child = childList.firstWhereOrNull((child) => child.get<String>(_fldName)!.toLowerCase() == newChildName.toLowerCase());

    if (child != null) {
      final query =  QueryBuilder<ParseObject>(ParseObject(_clsDevice));
      query.whereEqualTo(_fldChildID, child.objectId);

      final deviceList = await query.find();
      final device = deviceList.firstWhereOrNull((device) => device.get<String>(_fldName)!.toLowerCase() == newDeviceName.toLowerCase());

      if (device != null) {
        return ChildAndDeviceNames(child.get<String>(_fldName)!, device.get<String>(_fldName)!);
      }
    }

    if (child == null) {
      child = ParseObject(_clsChild);
      child.set<String>(_fldUserID, userID);
      child.set<String>(_fldName  , newChildName);
      await child.save();
    }

    final deviceID = await PlatformService.getDeviceID();

    final device = ParseObject(_clsDevice);
    device.set<String>(_fldUserID    , userID);
    device.set<String>(_fldChildID   , child.objectId!);
    device.set<String>(_fldName      , newDeviceName);
    device.set<String>(_fldDeviceOSID, deviceID);
    await device.save();

    return ChildAndDeviceNames(child.get<String>(_fldName)!, device.get<String>(_fldName)!);
  }

  /// Synchronizes the contents of the child's directories on the server and on the device
  /// Server -> Child
  /// missing directories, on server or device - NOT created
  /// returns a list of updated/added files
  Future<List<String>> synchronizeChild(Child child, {bool fromCommonFolder = false}) async {
    var netPath = path_util.join(child.name, child.deviceName);
    if (fromCommonFolder) netPath = _commonFolderName;

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsFile));
    query.whereEqualTo(_fldUserID, userID);
    query.whereEqualTo(_fldPath, netPath);

    final fileList = await query.find();

    final newFileList = <String>[];

    for (var file in fileList) {

      final fileName = file.get<String>(_fldFileName)!;
      final fileTime = file.updatedAt!;
      final fileSize = file.get<int>(_fldSize)!;

      final netFilePath = path_util.join(serverURL, netPath, fileName);

      if (!await child.dbSource.tabSourceFile.checkFileRegisteredEx(netFilePath, fileTime, fileSize)) {
        final filePath = path_util.join(child.downloadDir, fileName);
        final localFile = File(filePath);
        if (localFile.existsSync()) localFile.deleteSync();

        final content = file.get<ParseFile>(_fldContent)!;
        await content.loadStorage();
        if ( content.file == null){
          await content.download();
        }

        await content.file!.copy(filePath);

        await child.dbSource.tabSourceFile.registerFileEx(netFilePath, fileTime, fileSize);

        newFileList.add(fileName);
      }
    }

    return newFileList;
  }

  /// sends file to the server
  /// manager -> server
  Future<void> putFileToServer(Child child, String path) async {
    final fileName = path_util.basename(path);
    final netPath = path_util.join(child.name, child.deviceName);

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsFile));
    query.whereEqualTo(_fldUserID, userID);
    query.whereEqualTo(_fldPath, netPath);
    query.whereEqualTo(_fldFileName, fileName);

    {
      final serverFile = await query.first();
      if (serverFile != null) {
        await serverFile.delete();
      }
    }

    final localFile   =  File(path);
    final fileContent = localFile.readAsBytesSync();
    final fileSize    = await localFile.length();
    final techFileName = '${DateTime.now().millisecondsSinceEpoch}.data';

    final serverFileContent = ParseWebFile(fileContent, name : techFileName);
    await serverFileContent.save();

    final serverFile = ParseObject(_clsFile);
    serverFile.set<String>(_fldUserID  , userID);
    serverFile.set<String>(_fldPath    , netPath);
    serverFile.set<String>(_fldFileName, fileName);
    serverFile.set<int>(_fldSize, fileSize);
    serverFile.set<ParseWebFile>(_fldContent, serverFileContent);
    await serverFile.save();
  }

  void _setFromJson(ParseObject object, Map<String, dynamic> json) {
    for (var key in json.keys) {
      object.set(key, json[key]);
    }
  }

  /// saves tests results
  /// child -> server
  Future<void> saveTestsResults(Child child) async {
    final resultList = child.cardController.cardResultList;
    if (resultList.isEmpty) return;

    final childID = await _getChildID(child.name);

    for (var row in resultList) {
      final json = row.toJson();

      final testResult = ParseObject(_clsTestResult);
      _setFromJson(testResult, json);
      testResult.set<String>(_fldUserID , userID);
      testResult.set<String>(_fldChildID, childID);

      testResult.save();
    }

    resultList.clear();
  }

  /// Returns test results for a period
  /// server -> manager
  Future<List<TestResult>> getTestsResultsFromServer(Child child, int from, int to) async {
    final result = <TestResult>[];

    final childID = await _getChildID(child.name);

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsTestResult));
    query.whereEqualTo(_fldUserID, userID);
    query.whereEqualTo(_fldChildID, childID);
    query.whereGreaterThanOrEqualsTo(_fldDateTime, from);
    query.whereLessThanOrEqualTo(_fldDateTime, to);

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

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsStat));
    query.whereEqualTo(_fldUserID, userID);
    query.whereEqualTo(_fldChildID, childID);

    final statList = await query.find();

    final rows = await child.dbSource.tabCardStat.getAllRows();

    CardStatExchange.dbSource = child.dbSource;

    for (var row in rows) {
      final cse = CardStatExchange.fromDbMap(row);

      var stat = statList.firstWhereOrNull((stat) => stat.get(_fldFileGuid)! == cse.fileGuid && stat.get(_fldCardID)! == cse.cardID );
      if (stat == null) {
        stat = ParseObject(_clsStat);
        stat.set<String>(_fldUserID , userID);
        stat.set<String>(_fldChildID, childID);
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

    final query =  QueryBuilder<ParseObject>(ParseObject(_clsStat));
    query.whereEqualTo(_fldUserID, userID);
    query.whereEqualTo(_fldChildID, childID);

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
