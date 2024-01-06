import 'package:flutter/material.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

class HtmlViewWidgetWeb extends StatefulWidget {
  final String html;
  const HtmlViewWidgetWeb({required this.html, super.key});

  @override
  State<HtmlViewWidgetWeb> createState() => _HtmlViewWidgetWebState();
}

class _HtmlViewWidgetWebState extends State<HtmlViewWidgetWeb> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      var width = viewportConstraints.maxWidth;
      if (width == double.infinity) {
        width = MediaQuery.of(context).size.width;
      }

      var height = viewportConstraints.maxHeight;
      if (height == double.infinity) {
        height = MediaQuery.of(context).size.height * 2 / 3;
        if (height < viewportConstraints.minHeight) {
          height = viewportConstraints.minHeight;
        }
      }

      return WebViewX(
        key: const ValueKey('webviewx'),
        initialContent: widget.html,
        initialSourceType: SourceType.html,
        width: width,
        height: height,
      );
    });
  }
}