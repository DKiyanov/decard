import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class HtmlViewWidget extends StatefulWidget {
  final String html;
  const HtmlViewWidget({required this.html, Key? key}) : super(key: key);

  @override
  State<HtmlViewWidget> createState() => _HtmlViewWidgetState();
}

class _HtmlViewWidgetState extends State<HtmlViewWidget> {
  double htmlWidgetHeight = 1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: htmlWidgetHeight,

      child: InAppWebView(
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            supportZoom: false,
            javaScriptEnabled: true,
            disableHorizontalScroll: true,
            disableVerticalScroll: true,
          ),
        ),

        onLoadStop: (InAppWebViewController controller, Uri? url) async {
          final contentHeight = await controller.getContentHeight();
          if (contentHeight == null) return;
          setState(() {
            htmlWidgetHeight = contentHeight.toDouble();
          });
        },

        initialData: InAppWebViewInitialData( data: widget.html ),
      ),
    );
  }
}
