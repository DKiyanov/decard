import 'package:decard/common.dart';
import 'package:flutter/material.dart';

import 'card_model.dart';

class PackInfoWidget extends StatelessWidget {
  final PacInfo pacInfo;
  const PackInfoWidget({required this.pacInfo, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      row(TextConst.djfTitle        , pacInfo.title        ),
      row(TextConst.djfGuid         , pacInfo.guid         ),
      row(TextConst.djfVersion      , pacInfo.version.toString() ),
      row(TextConst.djfAuthor       , pacInfo.author       ),
      row(TextConst.djfSite         , pacInfo.site         ),
      row(TextConst.djfEmail        , pacInfo.email        ),
      row(TextConst.djfLicense      , pacInfo.license      ),
    ]);
  }

  Widget row(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Expanded(child: Text(title)),
          Expanded(child: Text(value)),
        ]),
      ),
    );
  }
}

Future<void> packInfoDisplay(BuildContext context, PacInfo file) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(TextConst.txtPackInfo),
        content: PackInfoWidget(pacInfo: file),
        scrollable: true,
      );
    },
  );
}
