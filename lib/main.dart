import 'package:flutter/material.dart';

import 'start_page.dart';

void main() async {
  runApp(
      MaterialApp(
        title: 'DeCard',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const StartPage(),
      )
  );
}
