import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import 'common.dart';
import 'file_source.dart';
import 'file_source_editor.dart';

class FileSourceListEditor extends StatefulWidget {
  static Future<List<FileSource>?> navigatorPush(BuildContext context, List<FileSource> fileSourceList) async {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => FileSourceListEditor(fileSourceList : fileSourceList)) );
  }

  const FileSourceListEditor({Key? key, required this.fileSourceList}) : super(key: key);
  final List<FileSource> fileSourceList;

  @override
  State<FileSourceListEditor> createState() => _FileSourceListEditorState();
}

class _FileSourceListEditorState extends State<FileSourceListEditor> {
  final _fileSourceList = <FileSource>[];

  @override
  void initState() {
    super.initState();

    _fileSourceList.addAll(widget.fileSourceList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
          Navigator.pop(context);
        }),
        centerTitle: true,
        title: Text(TextConst.txtTuningFileSourceList),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: (){
            Navigator.pop(context, _fileSourceList);
          })
        ],
      ),

      body: SafeArea(
          child: ListView(
            children: _fileSourceList.map((fileSource) =>

                Slidable(
                    startActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context){
                            _deleteDir(fileSource);
                          },
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: TextConst.txtDelete,
                        )
                      ],
                    ),

                    endActionPane: fileSource.type != FileSourceType.localPath?
                    ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context){
                            _editNetworkFileSource(fileSource);
                          },
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          icon: Icons.edit,
                          label: TextConst.txtEdit,
                        )
                      ],
                    ) : null,

                    child: ListTile(
                      title: Text(fileSource.toString()),
                    )
                ),

            ).toList(),
          )
      ),

      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,

        children: [
          SpeedDialChild(
            child: const Icon(Icons.folder, color: Colors.amber),
            label: TextConst.txtLocalDir,
            labelBackgroundColor: Colors.lightGreenAccent,
            backgroundColor: Colors.lightGreenAccent,
            onTap: ()=> _addLocalDir(),
          ),

          SpeedDialChild(
            child: const Icon(Icons.link, color: Colors.blue),
            label: TextConst.txtNetworkFileSource,
            labelBackgroundColor: Colors.lightGreenAccent,
            backgroundColor: Colors.lightGreenAccent,
            onTap: ()=> _addNetworkFileSource(),
          ),
        ],
      )
    );
  }

  Future<void> _addLocalDir() async {
    final String? selDir = await FilePicker.platform.getDirectoryPath();
    if (selDir != null && !_fileSourceList.any((fileSource) => fileSource.url == selDir)) {
      setState(() {
        _fileSourceList.add(FileSource(type: FileSourceType.localPath, url: selDir));
      });
    }
  }

  void _deleteDir(FileSource fileSource) {
    setState(() {
      _fileSourceList.remove(fileSource);
    });
  }

  Future<void> _addNetworkFileSource() async {
    final newFileSource = await FileSourceEditor.navigatorPush(context, TextConst.txtEditFileSource);
    if (newFileSource == null) return;

    setState(() {
      _fileSourceList.add(newFileSource);
    });
  }

  Future<void> _editNetworkFileSource(FileSource fileSource) async {
    final newFileSource = await FileSourceEditor.navigatorPush(context, TextConst.txtEditFileSource, fileSource);
    if (newFileSource == null) return;

    setState(() {
      final index = _fileSourceList.indexOf(fileSource);
      _fileSourceList.removeAt(index);
      _fileSourceList.insert(index, newFileSource);
    });
  }
}