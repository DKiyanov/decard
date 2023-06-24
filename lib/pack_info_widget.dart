import 'package:flutter/material.dart';

import 'card_model.dart';
import 'decardj.dart';

class PackInfoWidget extends StatelessWidget {
  final PacInfo pacInfo;
  const PackInfoWidget({required this.pacInfo, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: const [Text(DjfFile.title), Text(DjfFile.title)],)
    ]);
  }
}
