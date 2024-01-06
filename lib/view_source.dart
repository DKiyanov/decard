import 'media_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'card_model.dart';

class ViewContent extends StatefulWidget {
  static Future<Object?> navigatorPush(BuildContext context, CardData card, CardSource content, String title) async {
    return Navigator.push(context, MaterialPageRoute( builder: (_) => ViewContent(card: card, content: content, title: title)));
  }

  final CardData card;
  final CardSource content;
  final String title;
  const ViewContent({required this.card, required this.content, required this.title, Key? key}) : super(key: key);

  @override
  State<ViewContent> createState() => _ViewContentState();
}

class _ViewContentState extends State<ViewContent> {
  late String content;

  @override
  void initState() {
    super.initState();

    if (widget.content.type == FileExt.contentMarkdown) {
      content = FileExt.prepareMarkdown(widget.card, widget.content.data);
      return;
    }

    if (widget.content.type == FileExt.contentHtml) {
      content = FileExt.prepareHtml(widget.card, widget.content.data);
      return;
    }

    content = widget.content.data;
  }

  @override
  Widget build(BuildContext context) {
    Widget? body;

    if (widget.content.type == FileExt.contentMarkdown) {
      body = MarkdownBody(data: content);
    }

    if (widget.content.type == FileExt.contentHtml) {
      body = htmlView(content, widget.card.pacInfo.sourceDir);
    }

    if (widget.content.type == FileExt.contentImage) {
      final fileUrl = getFileUrl(content);
      body = imageFromUrl(fileUrl);
    }

    if (widget.content.type == FileExt.contentAudio) {
      final fileUrl = getFileUrl(content);
      body = audioPanelFromUrl(fileUrl, ValueKey(fileUrl));
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

  String getFileUrl(String fileName) {
    return widget.card.dbSource.getFileUrl(widget.card.pacInfo.jsonFileID, fileName)??fileName;
  }
}
