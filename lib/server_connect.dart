import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:decard/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path_util;

import 'child.dart';
import 'loader.dart';

class ServerConnect {
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
      return ChildAndDeviceNames(webFile.name!, deviceName);
    }

    await client.mkdir(path_util.join(childName, deviceName));
    return ChildAndDeviceNames(childName, deviceName);
  }

  /// Synchronizes the contents of the child's directories on the server and on the device
  /// missing directories, on server or device - NOT created
  Future<void> synchronizeChild(Child child, String childNameDir, String deviceNameDir) async {
    final client = getClient();

    final fileList = await client.readDir(path_util.join(childNameDir, deviceNameDir));

    for (var file in fileList) {
      if (getDecardFileType(file.path!) == DecardFileType.notDecardFile) continue;

      final fileName = path_util.basename(file.path!);

      final netFilePath = path_util.join(serverURL, childNameDir, deviceNameDir, fileName);

      if (!await child.dbSource.tabSourceFile.checkFileRegisteredEx(netFilePath, file.mTime!, file.size!)) {
        final filePath = path_util.join(child.downloadDir, fileName);
        final localFile = File(filePath);
        if (localFile.existsSync()) localFile.deleteSync();
        await client.read2File(file.path!, filePath);
        await child.dbSource.tabSourceFile.registerFileEx(netFilePath, file.mTime!, file.size!);
      }
    }
  }
}