import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';

import 'db.dart';
import 'file_source.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path_util;

import 'loader.dart';

/// создаёт локальные каталоги для сетевых источников
Future<void> prepareLocalPath(List<FileSource> fileSourceList, String selfDir, [String subDirPrefix = 'net']) async {
  int dirIndex = 0;

  for (var fileSource in fileSourceList) {
    if (fileSource.type != FileSourceType.localPath && fileSource.localPath.isEmpty) {
      Directory dir;
      do {
        dirIndex ++;
        dir = Directory(path_util.join(selfDir, '$subDirPrefix$dirIndex' ));
      } while (await dir.exists());
      await dir.create();
      fileSource.localPath = dir.path;
    }
  }
}

/// сканирование сетевых источников, загрузка файлов в локальные каталоги
Future<List<String>> scanNetworkFileSource(List<FileSource> fileSourceList, TabSourceFile tabSourceFile) async {
  final retErrList = <String>[];

  for (var fileSource in fileSourceList) {
    if (fileSource.type == FileSourceType.webDAV){
      try {
        await _scanWebDav(fileSource, tabSourceFile);
      }  catch (e) {
        String errStr = '';
        if (e is DioError) {
          errStr = e.message;
        } else {
          errStr = e.toString();
        }
        retErrList.add('${fileSource.url} $errStr');
      }
    }
  }

  return retErrList;
}

Future<void> _scanWebDav(FileSource fileSource, TabSourceFile tabSourceFile) async {
  final client = webdav.newClient(
    fileSource.url,
    user     : fileSource.login!,
    password : fileSource.password!,
  );

  final fileList = await client.readDir(fileSource.subPath!);

  for (var file in fileList) {
    if (getDecardFileType(file.path!) == DecardFileType.notDecardFile) continue;

    final fileName = path_util.basename(file.path!);

    String netFilePath = '';
    if (fileSource.subPath!.isEmpty) {
      netFilePath = '${fileSource.url}/$fileName';
    } else {
      netFilePath = '${fileSource.url}/${fileSource.subPath!}/$fileName';
    }

    if (!await tabSourceFile.checkFileRegisteredEx(netFilePath, file.mTime!, file.size!)) {
      final filePath = path_util.join(fileSource.localPath, fileName);
      final localFile = File(filePath);
      if (localFile.existsSync()) localFile.deleteSync();
      await client.read2File(file.path!, filePath);
      await tabSourceFile.registerFileEx(netFilePath, file.mTime!, file.size!);
    }
  }
}


Future<void> uploadData(FileSource fileSource, String fileName, Uint8List data) async {
  if (fileSource.type == FileSourceType.webDAV){
    await _uploadWebDav(fileSource, fileName, data);
  }
}

Future<void> _uploadWebDav(FileSource fileSource, String fileName, Uint8List data) async {
  final client = webdav.newClient(
    fileSource.url,
    user     : fileSource.login!,
    password : fileSource.password!,
  );

  await client.write(fileName, data);
}