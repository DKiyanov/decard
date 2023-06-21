import 'package:decard/app_state.dart';
import 'package:flutter/material.dart';

import 'card_demo.dart';
import 'common.dart';
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
