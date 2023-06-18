import 'package:decard/app_state.dart';
import 'package:flutter/material.dart';

import 'card_testing.dart';
import 'common.dart';

class ChildList extends StatefulWidget {
  const ChildList({Key? key}) : super(key: key);

  @override
  State<ChildList> createState() => _ChildListState();
}

class _ChildListState extends State<ChildList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(TextConst.txtManagement),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  child: Text(TextConst.txtSelectFile),
                  onTap: () {
                    // TODO select files for view anl then load to child
                  },
                )
              ];
            },
          ),
        ],
      ),

      body: SafeArea(child: ListView(
        children: appState.childList.map((child) => ListTile(
          title: Text('${child.name} ${child.deviceName}'),
          onTap: (){
            DeCard.navigatorPush(context, child);
          },
          trailing: Row( mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                onPressed: (){
                  // TODO Regulator.options tuning
                },
                icon: const Icon(Icons.tune)
            ),

            IconButton(
                onPressed: (){
                  // TODO statistics analysis
                },
                icon: const Icon(Icons.multiline_chart)
            ),
          ]),
        )).toList(),
      )),
    );
  }
}
