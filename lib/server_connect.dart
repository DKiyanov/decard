import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:decard/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path_util;

import 'child.dart';
import 'db.dart';

class ServerConnect {
  static const String _statDirName = "stat";
  static const String _statFilePrefix = "stat-";

  final SharedPreferences prefs;

  String serverURL = '';
  String login = '';
  String _password = '';

  bool   loggedIn = false;

  String lastError = '';

  ServerConnect(this.prefs){
    readConnectionParam();
  }

  Future<bool> setConnectionParam(String url, String newLogin, String password, bool signUp) async {
    serverURL = url;
    login     = newLogin;
    _password = password;

    await _saveConnectionParam();
    return await connectToServer();
  }

  Future<bool> connectToServer() async {
    if (serverURL.isEmpty || login.isEmpty || _password.isEmpty) {
      lastError = TextConst.errServerConnection1;
      return false;
    }

    final client = getClient();

    try {
      await client.ping();
      loggedIn = true;
    } catch (e) {
      loggedIn = false;
      lastError = e.toString();
    }

    return loggedIn;
  }

  webdav.Client getClient() {
    return webdav.newClient(
      serverURL,
      user     : login,
      password : _password,
    );
  }

  Future<void> _saveConnectionParam() async {
    final map = {
      "url"      : serverURL,
      "login"    : login,
      "password" : _password,
    };

    await prefs.setString("serverConnect", jsonEncode(map));
  }

  void readConnectionParam(){
    final json = prefs.getString("serverConnect") ?? "";
    if (json.isEmpty) return;
    final map = jsonDecode(json);

    serverURL = map["url"]??"";
    login     = map["login"]??"";
    _password = map["password"]??"";
  }

  Future<Map<String, List<String>>> getChildDeviceMap() async {
    final client = getClient();

    final Map<String, List<String>> result = {};

    final fileList = await client.readDir('');

    for (var webFile in fileList) {
      if (webFile.isDir!) {
        final subFileList = await client.readDir(webFile.path!);
        final deviceDirList = subFileList.where((webSubFile) => webSubFile.isDir!).map((webSubFile) => webSubFile.name!).toList();
        result[webFile.name!] = deviceDirList;
      }
    }

    return result;
  }

  Future<ChildAndDeviceNames> addChildDevice(String childName, String deviceName) async {
    final client = getClient();

    final fileList = await client.readDir('');

    final webFile = fileList.firstWhereOrNull((webFile) => webFile.name!.toLowerCase() == childName.toLowerCase());
    if (webFile != null) {
      final subFileList = await client.readDir(webFile.path!);
      final webSubFile = subFileList.firstWhereOrNull((webSubFile) => webSubFile.name!.toLowerCase() == deviceName.toLowerCase());
      if (webSubFile != null) return ChildAndDeviceNames(webFile.name!, webSubFile.name!);

      await client.mkdir(path_util.join(webFile.path!, deviceName));
      await client.mkdir(path_util.join(webFile.path!, deviceName, _statDirName));
      return ChildAndDeviceNames(webFile.name!, deviceName);
    }

    await client.mkdir(path_util.join(childName, deviceName));
    return ChildAndDeviceNames(childName, deviceName);
  }

  /// Synchronizes the contents of the child's directories on the server and on the device
  /// Server -> Child
  /// missing directories, on server or device - NOT created
  Future<List<String>> synchronizeChild(Child child) async {
    final client = getClient();

    final fileList = await client.readDir(path_util.join(child.name, child.deviceName));
    final newFileList = <String>[];

    for (var file in fileList) {
      if (file.isDir!) continue;

      final fileName = path_util.basename(file.path!);
      final netFilePath = path_util.join(serverURL, child.name, child.deviceName, fileName);

      if (!await child.dbSource.tabSourceFile.checkFileRegisteredEx(netFilePath, file.mTime!, file.size!)) {
        final filePath = path_util.join(child.downloadDir, fileName);
        final localFile = File(filePath);
        if (localFile.existsSync()) localFile.deleteSync();
        await client.read2File(file.path!, filePath);
        await child.dbSource.tabSourceFile.registerFileEx(netFilePath, file.mTime!, file.size!);

        newFileList.add(fileName);
      }
    }

    return newFileList;
  }

  /// saves tests results
  /// child -> server
  Future<void> saveTestsResults(Child child) async {
    final resultList = child.cardController.cardResultList;
    if (resultList.isEmpty) return;

    final fileName = '$_statFilePrefix${resultList.first.dateTime}-${resultList.last.dateTime.toString().substring(8)}.json';

    final jsonStr = jsonEncode(resultList);
    final fileData = Uint8List.fromList(jsonStr.codeUnits);

    final client = getClient();
    await client.write(path_util.join(child.name, child.deviceName, _statDirName, fileName), fileData);

    resultList.clear();
  }

  /// sends regulator data to the server
  /// manager -> server
  Future<void> putRegulatorToServer(Child child) async {
    final jsonStr = jsonEncode(child.regulator);
    final fileData = Uint8List.fromList(jsonStr.codeUnits);

    final client = getClient();
    await client.write(path_util.join(child.name, child.deviceName, Child.regulatorFileName), fileData);
  }

  /// sends file to the server
  /// manager -> server
  Future<void> putFileToServer(Child child, String path) async {
    final client = getClient();
    final fileName = path_util.basename(path);
    await client.writeFromFile(path, path_util.join(child.name, child.deviceName, fileName));
  }

  /// Returns test results for a period
  /// server -> manager
  Future<List<TestResult>> getTestsResultsFromServer(Child child, int from, int to) async {
	final result = <TestResult>[];
	
    final client = getClient();

    final fileList = await client.readDir(path_util.join(child.name, child.deviceName, _statDirName));
	
    for (var file in fileList) {
      if (file.isDir!) continue;
	  
      final fileName = file.name!;

      if (fileName.substring(0,5).toLowerCase() != _statFilePrefix) continue;

      final fileFrom = int.parse(fileName.substring(5,19));
      if (fileFrom > to) continue;

      final fileTo   = int.parse('${ fileName.substring(5,13) }${ fileName.substring(20,26) }');
      if (fileTo <= from) continue;

      final fileData = await client.read(file.path!);
      final jsonStr = utf8.decode(fileData);
      final jsonDataList = jsonDecode(jsonStr) as List;

      for (var row in jsonDataList) {
        final cardResult = TestResult.fromMap(row);
        if (cardResult.dateTime < from || cardResult.dateTime > to) continue;
        result.add(cardResult);
      }
    }

	  return result;
  }
}
