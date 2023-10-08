import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'audio_widget.dart';
import 'card_model.dart';
import 'html_widget.dart';
import 'dart:io';

class ViewContent extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, String path, String content, String title) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => ViewContent(path: path, content: content, title: title)));
  }

  final String path;
  final String content;
  final String title;
  const ViewContent({required this.path, required this.content, required this.title, Key? key}) : super(key: key);

  @override
  State<ViewContent> createState() => _ViewContentState();
}

class _ViewContentState extends State<ViewContent> {
  late String contentExt;
  late String content;

  @override
  void initState() {
    super.initState();

    contentExt = FileExt.getContentExt(widget.content);

    if (contentExt.isEmpty) {
      content = widget.content;
      return;
    }

    final str = widget.content.substring(contentExt.length + 1);

    if (contentExt == FileExt.contentText) {
      content = str;
      return;
    }

    if (contentExt == FileExt.contentMarkdown) {
      content = FileExt.prepareMarkdown(widget.path, str);
      return;
    }

    if (contentExt == FileExt.contentHtml) {
      content = FileExt.prepareHtml(widget.path, str);
      return;
    }

    content = str;
  }

  @override
  Widget build(BuildContext context) {
    Widget? body;

    if (contentExt == FileExt.contentMarkdown) {
      body = MarkdownBody(data: content);
    }

    if (contentExt == FileExt.contentHtml) {
      body = HtmlViewWidget(html: content, filesDir: widget.path);
    }

    if (FileExt.imageExtList.contains(contentExt)) {
      final path = FileExt.prepareFilePath(widget.path, content);
      final imgFile = File(path);
      if (imgFile.existsSync()) {
        body = Image.file( imgFile );
      }
    }

    if (FileExt.audioExtList.contains(contentExt)) {
      final path = FileExt.prepareFilePath(widget.path, content);
      final audioFile = File(path);
      if (audioFile.existsSync()) {
        body = AudioPanelWidget(
          key:  ValueKey(path),
          localFilePath : path
        );
      }
    }

    if (body == null && content.isNotEmpty) {
      body = Center(child: Text(content));
    }

    body ??= Container();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: body
    );
  }
}
