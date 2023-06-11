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

  Future<List<String>> getChildList() async {
    final client = getClient();

    final fileList = await client.readDir('');

    return fileList.where((webFile) => webFile.isDir == true).map((webFile) => webFile.name!).toList();
  }

  Future<String> addChild(String childName) async {
    final client = getClient();

    final fileList = await client.readDir('');

    final webFile = fileList.firstWhereOrNull((webFile) => webFile.name!.toLowerCase() == childName.toLowerCase());
    if (webFile != null) return webFile.name!;

    await client.mkdir(childName);
    return childName;
  }

  /// Синхронизирует содержимое каталогов ребёнка на сервере и на устройстве
  /// отсутствующие каталоги, на сервере или устройстве - НЕ создаются
  Future<void> synchronizeChild(Child child, String subDir) async {
    final client = getClient();

    final fileList = await client.readDir(subDir);

    for (var file in fileList) {
      if (getDecardFileType(file.path!) == DecardFileType.notDecardFile) continue;

      final fileName = path_util.basename(file.path!);

      final netFilePath = '$serverURL/$subDir/$fileName';

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