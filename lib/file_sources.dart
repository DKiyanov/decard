import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:filesystem_picker/filesystem_picker.dart';

import 'common.dart';

class LocalStorage {
  static Future<String?> getRootDir() async {
    final dirList = await getExternalStorageDirectories();
    if (dirList == null || dirList.isEmpty) return null;

    for (var dir in dirList) {
      final path = dir.path;
      final pos = path.indexOf('Android/data');
      if (pos < 0) continue;

      final rootPath = path.substring(0, pos - 1);
      return rootPath;
    }

    return null;
  }

  static Future<String?> getDownloadDir() async {
    final rootDir = (await getRootDir())!;
    final downloadPath = join(rootDir, 'Download') ;

    final downloadDir = Directory(downloadPath);
    if (!await downloadDir.exists()) return null;

    return downloadPath;
  }

  static Future<bool> checkPermission() async {
    final status = await Permission.storage.request(); //status;
    if (status != PermissionStatus.granted) {
      final result = await Permission.storage.request();
      if (result != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
}

class FileSources {
  static const String _kFileSourceList = 'fileSourceList';

  final SharedPreferences prefs;

  final items = <String>[];

  FileSources(this.prefs) {
    items.clear();

    final fileSourceList = prefs.getStringList(_kFileSourceList);
    if (fileSourceList != null) {
      items.addAll(fileSourceList);
    } else {
      _init();
    }
  }

  Future<void> _init() async {
    items.clear();

    final downloadPath = (await LocalStorage.getDownloadDir())!;
    items.add(downloadPath);

    _save();
  }

  Future<void> _save() async {
    await prefs.setStringList(_kFileSourceList, items);
  }

  Future<bool> edit(BuildContext context) async {
    final newFileSourceList = await FileSourcesEditor.navigatorPush(context, items);
    if (newFileSourceList == null) return false;
    if (listEquals(items, newFileSourceList)) return false;

    items.clear();
    items.addAll(newFileSourceList);
    await _save();

    return true;
  }
}

class FileSourcesEditor extends StatefulWidget {
  static Future<List<String>?> navigatorPush(BuildContext context, List<String> fileSourceList) async {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => FileSourcesEditor(fileSourceList: fileSourceList) ));
  }

  final List<String> fileSourceList;
  const FileSourcesEditor({required this.fileSourceList, Key? key}) : super(key: key);

  @override
  State<FileSourcesEditor> createState() => _FileSourcesEditorState();
}

class _FileSourcesEditorState extends State<FileSourcesEditor> {

  final _fileSourceList = <String>[];

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
        title: Text(TextConst.txtFileSources),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: (){
            Navigator.pop(context, _fileSourceList);
          })
        ],
      ),

      body: SafeArea(child: ListView(
        children: _fileSourceList.map((path) {
          return MyPopupMenu(
            items: [
              PopupMenuItem<String>(
                  value: TextConst.txtDelete,
                  child: Text(TextConst.txtDelete)
              )
            ],
            child: ListTile(title: Text(path)),
            onSelected: (value){
              if (value == TextConst.txtDelete) {
                setState(() {
                  _fileSourceList.remove(path);
                });
              }
            },
          );
        }).toList(),
      )),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final rootPath = (await LocalStorage.getRootDir())!;

          final path = await FilesystemPicker.openDialog(
              context: context,
              rootDirectory: Directory(rootPath),
              fsType: FilesystemType.folder
          );

          if (path == null) return;
          if (_fileSourceList.contains(path)) return;

          setState(() {
            _fileSourceList.add(path);
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class MyPopupMenu<T> extends StatefulWidget {
  final Widget child;
  final List<PopupMenuEntry<T>> items;
  final PopupMenuItemSelected<T>? onSelected;
  const MyPopupMenu({required this.child, required this.items, this.onSelected, Key? key}) : super(key: key);

  @override
  State<MyPopupMenu> createState() => _MyPopupMenuState<T>();
}

class _MyPopupMenuState<T> extends State<MyPopupMenu<T>> {
  TapDownDetails? _tapPosition;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: widget.child,
      onTapDown: (position) {
        _tapPosition = position;
      },
      onLongPress: (){
        _showContextMenu(context);
      },
    );
  }

  void _showContextMenu(BuildContext context) async {
    final renderBox = Overlay.of(context)?.context.findRenderObject() as RenderBox;
    final tapPosition = renderBox.globalToLocal(_tapPosition!.globalPosition);

    final result = await showMenu<T>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 100, 100),
          Rect.fromLTWH(0, 0, renderBox.paintBounds.size.width, renderBox.paintBounds.size.height)
        ),
        items: widget.items,
    );

    if (result == null) return;

    widget.onSelected?.call(result);
  }
}

