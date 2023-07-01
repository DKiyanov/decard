import 'package:decard/app_state.dart';
import 'package:flutter/material.dart';

import 'card_set_list.dart';
import 'card_demo.dart';
import 'child_statistics.dart';
import 'common.dart';
import 'difficulty_list.dart';
import 'manager_file_list.dart';

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
                  value: TextConst.txtSelectFile,
                  child: Text(TextConst.txtSelectFile),
                )
              ];
            },
            onSelected: (value){
              if (value == TextConst.txtSelectFile) {
                FileList.navigatorPush(context);
                setState(() {});
              }
            },
          ),
        ],
      ),

      body: SafeArea(child: ListView(
        children: appState.childList.map((child) => ListTile(
          title: Text('${child.name} ${child.deviceName}'),
          onTap: (){
            DeCardDemo.navigatorPush(context, child);
          },
          trailing: Row( mainAxisSize: MainAxisSize.min, children: [
            PopupMenuButton<VoidCallback>(
              icon: const Icon(Icons.tune),
              itemBuilder: (context) {
                return [
                  PopupMenuItem<VoidCallback>(
                    value: () {

                    },
                    child: Text(TextConst.txtRegOptions),
                  ),

                  PopupMenuItem<VoidCallback>(
                    value: () {
                      CardSetList.navigatorPush(context, child);
                    },
                    child: Text(TextConst.txtRegCardSet),
                  ),

                  PopupMenuItem<VoidCallback>(
                    value: () async {
                      final result = await DifficultyList.navigatorPush(context, child);
                      if (result != null && result) {
                        child.refreshRegulator();
                      }
                    },
                    child: Text(TextConst.txtRegDifficultyLevelsTuning),
                  ),

                ];
              },
              onSelected: (value){
                value.call();
              },
            ),

            IconButton(
                onPressed: (){
                  ChildStatistics.navigatorPush(context, child, appState.prefs);
                },
                icon: const Icon(Icons.multiline_chart)
            ),
          ]),
        )).toList(),
      )),
    );
  }
}
