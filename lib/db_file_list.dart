import 'package:decard/app_state.dart';
import 'package:flutter/material.dart';

import 'card_model.dart';
import 'common.dart';

class DbFileList extends StatefulWidget {
  static Future<Object?> navigatorPushReplacement(BuildContext context) async {
    return Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DbFileList() ));
  }

  const DbFileList({Key? key}) : super(key: key);

  @override
  State<DbFileList> createState() => _DbFileListState();
}

class _DbFileListState extends State<DbFileList> {
  final _fileList = <PacInfo>[];
  bool _isStarting = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await _refreshFileList();

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> _refreshFileList() async {
    final rows = await appState.dbSource.tabJsonFile.getAllRows();
    _fileList.clear();
    _fileList.addAll(rows.map((row) => PacInfo.fromMap(row)));
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
        title: Text(TextConst.txtDbFileListTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            itemBuilder: (context) {
              return [
                TextConst.txtDownloadNewFiles,
              ].map<PopupMenuItem<String>>((value) => PopupMenuItem<String>(
                value: value,
                child: Text(value),
              )).toList();
            },
            onSelected: (value) async {
              if (value == TextConst.txtDownloadNewFiles) {
                downloadNewFiles();
              }
            },
          ),
        ],
      ),

      body: SafeArea(
          child: ListView.builder(
            itemCount: _fileList.length,
            itemBuilder: _buildFileItem,
          )
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, int index) {
    final file = _fileList[index];

    return ExpansionTile(
      title: Text(file.title),
      subtitle: Text(file.filename),
      children: [
        Row(children: [const Text('автор'), Text(file.author)]),
        Row(children: [const Text('E-Mail'), Text(file.email)]),
      ],
    );
  }

  Future<void> downloadNewFiles() async {
    appState.editFileSourceList(context);
    await _refreshFileList();
    setState(() {});
  }
}
