import 'package:decard/regulator.dart';
import 'package:flutter/material.dart';

import 'card_model.dart';
import 'card_set_widget.dart';
import 'child.dart';
import 'common.dart';

class CardSetList extends StatefulWidget {
  static Future<bool?> navigatorPush(BuildContext context, Child child) async {
    return Navigator.push<bool>(context, MaterialPageRoute( builder: (_) => CardSetList(child: child)));
  }

  final Child child;

  const CardSetList({required this.child, Key? key}) : super(key: key);

  @override
  State<CardSetList> createState() => _CardSetListState();
}

class _CardSetListState extends State<CardSetList> {
  bool _isStarting = true;
  late Regulator _regulator;
  late List<PacInfo> _fileList;

  final _newCardSetList = <RegCardSet>[];

  PacInfo? _selFile;
  final _cardSetList        = <RegCardSet>[];
  final _selFileCardKeyList = <String>[];
  final _selFileGroupList   = <String>[];
  final _selFileTagList     = <String>[];
  final _selDifficultyList  = <String>[];

  bool _changed = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    for (int level = Regulator.lowDifficultyLevel; level <= Regulator.highDifficultyLevel; level++) {
      _selDifficultyList.add(level.toString());
    }

    _regulator = await Regulator.fromFile( widget.child.regulatorPath );
    await _getChildFileList();

    _setSelFile(_fileList.first);

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> _getChildFileList() async {
    final fileRows = await widget.child.dbSource.tabJsonFile.getAllRows();
    if (fileRows.isEmpty) return;

    _fileList = fileRows.map((row) => PacInfo.fromMap(row)).toList();

    _fileList.sort((a, b) => a.jsonFileID.compareTo(b.jsonFileID));
  }

  Future<void> _setSelFile(PacInfo file) async {
    if (_selFile != null && _selFile!.guid == file.guid) return;

    if (_selFile != null) {
      _regulator.cardSetList.removeWhere((testFile) => testFile.fileGUID == _selFile!.guid);
      _regulator.cardSetList.addAll(_cardSetList);
    }

    _selFile = file;

    _cardSetList.clear();
    _cardSetList.addAll(_regulator.cardSetList.where((cardSet) => cardSet.fileGUID == _selFile!.guid));

    _selFileCardKeyList.clear();
    _selFileCardKeyList.addAll(await widget.child.dbSource.tabCardHead.getFileCardKeyList(jsonFileID: _selFile!.jsonFileID));

    _selFileGroupList.clear();
    _selFileGroupList.addAll(await widget.child.dbSource.tabCardHead.getFileGroupList(jsonFileID: _selFile!.jsonFileID));

    _selFileTagList.clear();
    _selFileTagList.addAll(await widget.child.dbSource.tabCardTag.getFileTagList(jsonFileID: _selFile!.jsonFileID));
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(TextConst.txtStarting),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: (){
          Navigator.pop(context, false);
        }),
        centerTitle: true,
        title: Text(TextConst.txtCardSetTuning),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: ()=> _saveAndExit() )
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            _fileSelector(),

            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.all(10.0),
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _cardSetList.removeAt(oldIndex);
                    _cardSetList.insert(newIndex, item);
                    _changed = true;
                  });
                },
                children: _body(),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon( Icons.add),
        onPressed: () {
          _addCardSet();
        },
      ),
    );
  }

  Widget _fileSelector() {
    return Row( mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(TextConst.txtFile, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        Container(width: 10),
        DropdownButton<PacInfo>(
          value: _selFile,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: (value) {
            setState(() {
              _setSelFile(value!);
            });
          },
          items: _fileList.map((file) => DropdownMenuItem<PacInfo>(
            value: file,
            child: Text(file.title),
          )).toList(),
        ),
      ],
    );
  }

  List<Widget> _body() {
    final result = <Widget>[];

    for (int index = 0; index < _cardSetList.length; index += 1) {
      final item = _cardSetList[index];
      result.add(Card(
        key: ValueKey(item), // for ordering and CardSetWidget
        color: Colors.grey,
        child: CardSetWidget(
          cardSet         : item,
          editing         : _newCardSetList.contains(item),
          showDelButton   : !_newCardSetList.contains(item),
          allCardList     : _selFileCardKeyList,
          allGroupList    : _selFileGroupList,
          allTagList      : _selFileTagList,
          allDifficulties : _selDifficultyList,
          onChange        : (newCardSet) {
            setState(() {
              _changed = true;
              final index = _cardSetList.indexOf(item);
              _cardSetList.removeAt(index);
              _cardSetList.insert(index, newCardSet);

              _newCardSetList.remove(item);
              _newCardSetList.remove(newCardSet);
            });
          },
          onCancelEditing: () {
            if (_newCardSetList.contains(item)) {
              setState(() {
                _cardSetList.remove(item);
              });
            }
          },
          onDelete: () {
            setState(() {
              _changed = true;
              _cardSetList.remove(item);
            });
          },
        ),
      ));
    }

    return result;
  }

  void _addCardSet() {
    setState((){
      _changed = true;
      final newCardSet = RegCardSet(fileGUID : _selFile!.guid);
      _newCardSetList.add(newCardSet);
      _cardSetList.add(newCardSet);
    });
  }

  Future<void> _saveAndExit() async {
    if (_changed) {
      await _regulator.saveToFile(widget.child.regulatorPath);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
