import 'dart:io';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:path/path.dart' as path_util;

import 'db.dart';
import 'loader.dart';

class LocalPackLoader {
  String _selfDir = '';
  int _dirIndex = 0;
  final errorList = <String>[];

  static const String _subDirPrefix = 'j'; // subdirectory name prefix

  DbSource? _dbSource;

  int _loadCount = 0;

    /// Scans the list of directories and selects files with extensions: '.decardz', '.decardj'
  /// The '.decardz' files are unpacked into subdirectories, prefix for subdirectories [_subDirPrefix]
  /// The '.decardj' data is stored in the database
  /// version control is performed compared to what was previously loaded into the database
  Future<int> refreshDB({ required List<String> dirForScanList, required String selfDir, required DbSource dbSource}) async {
    _selfDir = selfDir;
    _dbSource = dbSource;
    errorList.clear();
    _loadCount = 0;

    for (var dir in dirForScanList) {
      await _scanDir(dir);
    }
    if (_loadCount == 0) return 0;

    await dbSource.init();

    return _loadCount;
  }

  Future<void> _scanDir(String dir) async {
    // in API 33 problem with receive file list on external storage
    // need permission MANAGE_EXTERNAL_STORAGE
    // https://android-tools.ru/coding/poluchaem-razreshenie-manage_external_storage-dlya-prilozheniya/
    final fileList = Directory(dir).listSync( recursive: true);

    for (var object in fileList) {
      if (object is File){
        final File file = object;
        final fileType = getDecardFileType(file.path);

        if ([DecardFileType.zip, DecardFileType.json].contains(fileType)) {
          if (await _checkFileIsNoRegistered(file)) {

            final regID = await _registerFile(file);
            final dir = await _getNextDir();

            if (fileType == DecardFileType.zip) {
              await ZipFile.extractToDirectory(zipFile: file, destinationDir: dir);
            }
            if (fileType == DecardFileType.json) {
              final newPath = path_util.join(dir.path, path_util.basename(file.path));
              await file.copy(newPath);
            }

            file.delete();
            final dirSource = await getDirSource(dir.path);

            final jsonFileID = await loadPack(_dbSource!, 'localFile:$regID', dirSource!, onlyLastVersion: true, reInitDB: false);

            if (jsonFileID == null) {
              continue;
            }

            _loadCount ++;
          }
        }

      }
    }
  }

  Future<int> _registerFile(File file) async {
    return await _dbSource!.tabSourceFile.registerFile(file.path, await file.lastModified(), file.lengthSync());
  }

  Future<bool> _checkFileIsNoRegistered(File file) async {
    return ! await _dbSource!.tabSourceFile.checkFileRegistered(file.path, await file.lastModified(), file.lengthSync());
  }

  Future<Directory> _getNextDir() async {
    Directory dir;
    do {
      _dirIndex ++;
      dir = Directory(path_util.join(_selfDir, '$_subDirPrefix$_dirIndex' ));
    } while (await dir.exists());
    await dir.create();

    return dir;
  }
}

Future<Map<String, String>?> getDirSource(String path) async {
  final Map<String, String> fileUrlMap = {};

  final dir = Directory(path);

  final fileList = dir.listSync( recursive: true);

  for (var object in fileList) {
    if (object is File){
      final File file = object;

      final relPath = path_util.relative(file.path, from: path);
      fileUrlMap[relPath] = file.path;
    }
  }

  return fileUrlMap;
}
