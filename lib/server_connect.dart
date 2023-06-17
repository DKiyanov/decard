import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:decard/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path;

import 'child.dart';
import 'loader.dart';

class ServerConnect {
  static const String _statDirName = "stat";

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

      await client.mkdir(path.join(webFile.path!, deviceName));
      await client.mkdir(path.join(webFile.path!, deviceName, _statDirName));
      return ChildAndDeviceNames(webFile.name!, deviceName);
    }

    await client.mkdir(path.join(childName, deviceName));
    return ChildAndDeviceNames(childName, deviceName);
  }

  /// Synchronizes the contents of the child's directories on the server and on the device
  /// Server -> Child
  /// missing directories, on server or device - NOT created
  Future<void> synchronizeChild(Child child) async {
    final client = getClient();

    final fileList = await client.readDir(path.join(child.name, child.deviceName));

    for (var file in fileList) {
      if (file.isDir!) continue;

      final fileName = path.basename(file.path!);

      late String downloadDir;
      bool isRegulator = false;

      if (fileName.toLowerCase() == Child.regulatorFileName) {
        downloadDir = child.rootDir;
        isRegulator = true;
      } else {
        if (getDecardFileType(fileName) == DecardFileType.notDecardFile) continue;
        downloadDir = child.downloadDir;
      }

      final netFilePath = path.join(serverURL, child.name, child.deviceName, fileName);

      if (!await child.dbSource.tabSourceFile.checkFileRegisteredEx(netFilePath, file.mTime!, file.size!)) {
        final filePath = path.join(downloadDir, fileName);
        final localFile = File(filePath);
        if (localFile.existsSync()) localFile.deleteSync();
        await client.read2File(file.path!, filePath);
        await child.dbSource.tabSourceFile.registerFileEx(netFilePath, file.mTime!, file.size!);

        if (isRegulator) {
          await child.refreshRegulator();
        } else {
          await child.refreshCardsDB();
        }
      }
    }
  }

  /// saves tests results
  Future<void> saveTestsResults(Child child) async {
    final resultList = child.cardController.cardResultList;
    if (resultList.isEmpty) return;

    final fileName = 'stat-${resultList.first.dateTime}-${resultList.last.dateTime.toString().substring(8)}.json';

    final jsonStr = jsonEncode(resultList);
    final fileData = Uint8List.fromList(jsonStr.codeUnits);

    final client = getClient();
    await client.write(path.join(child.name, child.deviceName, _statDirName, fileName), fileData);

    resultList.clear();
  }
}