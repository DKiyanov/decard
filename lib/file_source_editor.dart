import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'common.dart';
import 'file_source.dart';

class FileSourceEditor extends StatefulWidget {
  static Future<FileSource?> navigatorPush(BuildContext context, String title, [FileSource? fileSource]) async {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => FileSourceEditor(title : title, fileSource: fileSource)) );
  }

  final String title;
  final FileSource? fileSource;

  const FileSourceEditor({this.fileSource, required this.title, Key? key}) : super(key: key);

  @override
  State<FileSourceEditor> createState() => _FileSourceEditorState();
}

class _FileSourceEditorState extends State<FileSourceEditor> {
  final urlController      = TextEditingController();
  final subPathController  = TextEditingController();
  final loginController    = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.fileSource != null){
      urlController.text      = widget.fileSource!.url;
      subPathController.text  = widget.fileSource!.subPath!;
      loginController.text    = widget.fileSource!.login!;
      passwordController.text = widget.fileSource!.password!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
            Navigator.pop(context);
          }),
          centerTitle: true,
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.lightGreen),
              onPressed: checkAndExit
            )
          ],
        ),

        body: SafeArea(
          child: ListView(
            children: body(),
          ),
        )
    );
  }

  List<Widget> body(){
    final widgetList = <Widget>[];

    widgetList.add(
      Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child:
        TextField(
          controller: urlController,
          decoration: InputDecoration(
            labelText: TextConst.txtUrl,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blue),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        )
      )
    );

    widgetList.add(
      Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child:
        TextField(
          controller: subPathController,
          decoration: InputDecoration(
            labelText: TextConst.txtSubPath,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blue),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        )
      )
    );

    widgetList.add(
      Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child:
        TextField(
          controller: loginController,
          decoration: InputDecoration(
            labelText: TextConst.txtLogin,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blue),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        )
      )
    );

    widgetList.add(
      Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child:
        TextField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: TextConst.txtPassword,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(width: 3, color: Colors.blue),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        )
      )
    );

    return widgetList;
  }

  FileSourceType? getFileSourceTypeFormUrl(String url){
    final protocolStr = url.split('://').first.toLowerCase();

    if (["http", "https"].contains(protocolStr)) {
      return FileSourceType.webDAV;
    }

    return null;
  }

  void checkAndExit() {
    if (widget.fileSource == null || (widget.fileSource != null && (
      urlController.text      != widget.fileSource!.url      ||
      subPathController.text  != widget.fileSource!.subPath! ||
      loginController.text    != widget.fileSource!.login!   ||
      passwordController.text != widget.fileSource!.password!
    ))) {
      final fileSourceType = getFileSourceTypeFormUrl(urlController.text);
      if (fileSourceType == null) {
        Fluttertoast.showToast(msg: TextConst.txtInvalidUrl);
        return;
      }

      final newFileSource = FileSource(
        type     : fileSourceType,
        url      : urlController.text,
        subPath  : subPathController.text,
        login    : loginController.text,
        password : passwordController.text
      );

      Navigator.pop(context, newFileSource);
      return;
    }

    Navigator.pop(context);
  }
}
