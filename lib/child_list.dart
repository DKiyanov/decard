import 'package:decard/app_state.dart';
import 'package:decard/simple_menu.dart';
import 'package:flutter/material.dart';

import 'card_set_list.dart';
import 'card_demo.dart';
import 'child.dart';
import 'child_statistics.dart';
import 'common.dart';
import 'difficulty_list.dart';
import 'manager_file_list.dart';
import 'options_editor.dart';

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
          popupMenu(
              icon: const Icon(Icons.menu),
              menuItemList: [
                SimpleMenuItem(
                    child: Text(TextConst.txtSelectFile),
                    onPress: () {
                      FileList.navigatorPush(context);
                      setState(() {});
                    }
                )
              ]
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
            popupMenu(
                icon: const Icon(Icons.tune),
                menuItemList: [
                  SimpleMenuItem(
                      child: Text(TextConst.txtRegOptions),
                      onPress: () async {
                        final result = await OptionsEditor.navigatorPush(context, child);
                        if (result != null && result) {
                          refreshChildRegulator(child);
                        }
                      }
                  ),

                  SimpleMenuItem(
                      child: Text(TextConst.txtRegCardSet),
                      onPress: () async {
                        final result = await CardSetList.navigatorPush(context, child);
                        if (result != null && result) {
                          refreshChildRegulator(child);
                        }
                      }
                  ),

                  SimpleMenuItem(
                      child: Text(TextConst.txtRegDifficultyLevelsTuning),
                      onPress: () async {
                        final result = await DifficultyList.navigatorPush(context, child);
                        if (result != null && result) {
                          refreshChildRegulator(child);
                        }
                      }
                  ),
                ]
            ),

            IconButton(
                onPressed: (){
                  ChildStatistics.navigatorPush(context, child);
                },
                icon: const Icon(Icons.multiline_chart)
            ),
          ]),
        )).toList(),
      )),
    );
  }

  Future<void> refreshChildRegulator(Child child) async {
    await child.refreshRegulator();
    await appState.serverFunctions.putFileToServer(child, child.regulatorPath);
  }
}
