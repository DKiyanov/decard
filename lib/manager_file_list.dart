import 'package:decard/app_state.dart';
import 'package:flutter/material.dart';

import 'card_demo.dart';
import 'card_model.dart';
import 'child.dart';
import 'common.dart';

class FileList extends StatefulWidget {
  const FileList({Key? key}) : super(key: key);

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  bool _isStarting = true;
  late List<PacInfo> _fileList;

  late Child _child;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    _child = appState.viewFileChild;
    await getDbInfo();

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> getDbInfo() async {
    final fileRows = await _child.dbSource.tabJsonFile.getAllRows();
    if (fileRows.isEmpty) return;

    _fileList = fileRows.map((row) => PacInfo.fromMap(row)).toList();
    _fileList.sort((a, b) => a.jsonFileID.compareTo(b.jsonFileID));
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
                  child: Text(TextConst.txtFileSources),
                  onTap: () {
                    // TODO open file source list editor
                  },
                )
              ];
            },
          ),
        ],
      ),

      body: SafeArea(child: ListView(
        children: _fileList.map((file) {
          return ListTile(
            title: Text(file.title),
            onTap: () {
              DeCardDemo.navigatorPush(context, _child, fileGuid: file.guid, onlyThatFile: true);
            }
          );
        }).toList(),
      )),
    );

  }
}
