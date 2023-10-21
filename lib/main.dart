import 'package:flutter/material.dart';

import 'start_page.dart';

void main() async {
  runApp( const DecardApp() );
}

class DecardApp extends StatelessWidget {
  const DecardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {

      const designSize = Size(411.42857142857144, 797.7142857142857);
      double scale = 1.0;

      final wScale = viewportConstraints.maxWidth / designSize.width;
      final hScale = viewportConstraints.maxHeight/ designSize.height;
      if (wScale < hScale) {
        scale = wScale;
      } else {
        scale = hScale;
      }

      if (scale < 0.8) {
        scale = 0.8;
      }

      return MaterialApp(
        title: 'DeCard',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          textTheme: Theme.of(context).textTheme.apply(
            fontSizeFactor: scale,
          ),
          iconTheme: IconThemeData( size: 24 * scale),
        ),
        home: const StartPage(),
      );
    });
  }
}
