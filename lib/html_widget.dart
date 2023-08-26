import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class HtmlViewWidget extends StatefulWidget {
  final String html;
  final String filesDir;
  const HtmlViewWidget({required this.html, required this.filesDir, Key? key}) : super(key: key);

  @override
  State<HtmlViewWidget> createState() => _HtmlViewWidgetState();
}

class _HtmlViewWidgetState extends State<HtmlViewWidget> {
  double htmlWidgetHeight = 1;

  @override
  Widget build(BuildContext context) {
    // for correct operation, the html must contain the line:
    // <meta name="viewport" content="width=device-width, initial-scale=1.0">
    return SizedBox(
      height: htmlWidgetHeight,

      child: InAppWebView(
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            disableHorizontalScroll: true,
            disableVerticalScroll: true,
          ),
        ),

        onLoadStop: (InAppWebViewController controller, Uri? url) async {
          final contentHeight = await controller.getContentHeight();
          if (contentHeight == null) return;
          htmlWidgetHeight = contentHeight.toDouble();
          setState(() {});
        },

         initialData: InAppWebViewInitialData(
             data: widget.html,
             baseUrl:  Uri(scheme: 'file', path: widget.filesDir)
         ),
      ),
    );
  }
}
