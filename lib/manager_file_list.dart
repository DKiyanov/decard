import 'package:decard/app_state.dart';
import 'package:decard/db.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'card_demo.dart';
import 'card_model.dart';
import 'child.dart';
import 'common.dart';
import 'file_sources.dart';

class FileList extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context) async {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => const FileList() ));
  }
  const FileList({Key? key}) : super(key: key);

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  bool _isStarting = true;
  late List<PacInfo> _fileList;
  final Map<PacInfo, String> _pathMap = {};

  late Child _viewFileChild;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    _viewFileChild = appState.viewFileChild;
    await scanFileSources();
    await getDbInfo();

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> getDbInfo() async {
    final fileRows = await _viewFileChild.dbSource.tabJsonFile.getAllRows();
    if (fileRows.isEmpty) {
      _fileList = [];
      return;
    }

    _fileList = fileRows.map((row) => PacInfo.fromMap(row)).toList();
    _fileList.sort((a, b) => a.jsonFileID.compareTo(b.jsonFileID));

    final toDelFileList = <PacInfo>[];

    for (var file in _fileList) {
      final sourceRow = await _viewFileChild.dbSource.tabSourceFile.getRow(sourceFileID: file.sourceFileID);
      final String path = sourceRow![TabSourceFile.kFilePath]??'';
      final deviceFile = File(path);
      if (deviceFile.existsSync()) {
        _pathMap[file] = path;
      } else {
        toDelFileList.add(file);
      }
    }

    for (var file in toDelFileList) {
      await _viewFileChild.dbSource.deleteJsonFile(file.jsonFileID);
      _fileList.remove(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(TextConst.txtStarting),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(TextConst.txtAvailableFiles),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: TextConst.txtRefreshFileList,
                  child: Text(TextConst.txtRefreshFileList)
                ),
                PopupMenuItem(
                  value: TextConst.txtFileSources,
                  child: Text(TextConst.txtFileSources)
                )
              ];
            },
            onSelected: (value) async {
              if (value == TextConst.txtRefreshFileList) {
                scanFileSources();
              }

              if (value == TextConst.txtFileSources) {
                if (await appState.fileSources.edit(context)) {
                  scanFileSources();
                }
              }
            },
          ),
        ],
      ),

      body: SafeArea(child: ListView(
        children: _fileList.map((file) {
          return ListTile(
            title: Text(file.title),
            onTap: () {
              DeCardDemo.navigatorPush(context, _viewFileChild, fileGuid: file.guid, onlyThatFile: true);
            },
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down_outlined),
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    value: TextConst.txtUploadFileToChild,
                    child: Text(TextConst.txtUploadFileToChild),
                  ),
                  PopupMenuItem<String>(
                    value: TextConst.txtDelete,
                    child: Text(TextConst.txtDelete),
                  )
                ];
              },
              onSelected: (value) async {
                if (value == TextConst.txtUploadFileToChild) {
                  await setFileToChildWithDialog(context, file);
                  setState(() {});
                }

                if (value == TextConst.txtDelete) {
                  if (!mounted) return;
                  if (await deleteFileWithDialog(context, file)) {
                    setState(() {});
                  }
                }
              },
            ),
          );
        }).toList(),
      )),
    );
  }

  Future<void> scanFileSources() async {
    if (appState.fileSources.items.isNotEmpty) {
      if (await LocalStorage.checkPermission()) {
        await appState.viewFileChild.refreshCardsDB(appState.fileSources.items);
      }
    }
  }

  Future<void> setFileToChild(Child child, PacInfo file) async {
    await appState.serverConnect.putFileToServer(child, _pathMap[file]!);
    await appState.serverConnect.synchronizeChild(child);
  }

  Future<void> setFileToChildWithDialog(BuildContext context, PacInfo file) async {
    if (appState.childList.isEmpty) return;

    final selChildList = <Child>[];

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(TextConst.txtUploadFileToChild),
          content: SingleChildScrollView(
            child: ListBody(
                children: appState.childList.map((child) => ListTile(
                  title: Text(child.name),
                  trailing: StatefulBuilder(
                    builder: (context, setState) {
                      return Checkbox(
                        value: selChildList.contains(child),
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              selChildList.add(child);
                            } else {
                              selChildList.remove(child);
                            }
                          });
                        },
                      );
                    },
                  ),
                )).toList()
            ),
          ),
          actions: <Widget>[

            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent,),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),

            IconButton(
              icon: const Icon(Icons.check, color: Colors.lightGreen),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),

          ],
        );
      },
    );

    if (result == null || !result) return;

    for (var child in selChildList) {
      setFileToChild(child, file);
    }
  }


  Future<bool> deleteFileWithDialog(BuildContext context, PacInfo file) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(TextConst.txtWarning),
          content: Text(TextConst.txtDeleteFile),
          actions: <Widget>[

            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent,),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),

            IconButton(
              icon: const Icon(Icons.check, color: Colors.lightGreen),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),

          ],
        );
      },
    );

    if (result == null || !result) return false;

    final path = _pathMap[file]!;
    final deviceFile = File(path);
    deviceFile.deleteSync();

    await _viewFileChild.dbSource.deleteJsonFile(file.jsonFileID);
    _fileList.remove(file);

    return true;
  }

}
