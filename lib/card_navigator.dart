import 'package:decard/common.dart';
import 'package:flutter/material.dart';

import 'card_model.dart';
import 'child.dart';

class CardNavigator extends StatefulWidget {
  final Child child;
  final String fileGuid;
  final bool   onlyThatFile;
  const CardNavigator({required this.child, this.fileGuid = '', this.onlyThatFile = false, Key? key}) : super(key: key);

  @override
  State<CardNavigator> createState() => _CardNavigatorState();
}

class _CardNavigatorState extends State<CardNavigator> {
  bool _isStarting = true;
  late List<PacInfo> _fileList;
  late List<CardHead> _cardList;

  PacInfo? _selFile;
  final _selFileCardList = <CardHead>[];
  CardHead? _selCard;
  int _selBodyNum = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _starting();
    });
  }

  void _starting() async {
    await getDbInfo();

    setState(() {
      _isStarting = false;
    });
  }

  Future<void> getDbInfo() async {
    final fileRows = await widget.child.dbSource.tabJsonFile.getAllRows();
    if (fileRows.isEmpty) return;

    _fileList = fileRows.map((row) => PacInfo.fromMap(row)).toList();

    if (widget.onlyThatFile) {
      _fileList.removeWhere((file) => file.guid != widget.fileGuid);
    }

    _fileList.sort((a, b) => a.jsonFileID.compareTo(b.jsonFileID));

    final cardRows = await widget.child.dbSource.tabCardHead.getAllRows();
    if (cardRows.isEmpty) return;

    _cardList = cardRows.map((row) => CardHead.fromMap(row)).toList();
    _cardList.sort((a, b) => a.cardID.compareTo(b.cardID));

    if (widget.fileGuid.isNotEmpty) {
      final file = _fileList.firstWhere((file) => file.guid == widget.fileGuid);
      setSelFile(file);
    } else {
      setSelFile(_fileList.first);
    }

    setFirstCard();
    setSelected();
  }

  void setSelFile(PacInfo file){
    _selFile = file;
    _selFileCardList.clear();
    _selFileCardList.addAll(_cardList.where((card) => card.jsonFileID == _selFile!.jsonFileID));
  }

  void setFirstCard() {
    _selCard = _selFileCardList.first;
    _selBodyNum = 0;
  }
  
  void setFileDirect(int direct) {
    if (_selFile == null) return;
    
    var index = _fileList.indexOf(_selFile!);
    index = index + direct;
    if (index < 0) return;
    if (index >= _fileList.length) return;

    setSelFile(_fileList[index]);
    setFirstCard();

    setSelected();
  }

  void setCardDirect(int direct) {
    if (_selCard == null) return;

    var index = _selFileCardList.indexOf(_selCard!);
    index = index + direct;
    if (index < 0) return;
    if (index >= _selFileCardList.length) return;

    _selCard = _selFileCardList[index];
    _selBodyNum = 0;

    setSelected();
  }

  void setBodyNumDirect(int direct) {
    if (_selCard == null) return;
    final newBodyNum = _selBodyNum + direct;
    if (newBodyNum < 0) return;
    if (newBodyNum >= _selCard!.bodyCount) return;

    _selBodyNum = newBodyNum;

    setSelected();
  }

  void setSelected() {
    setState(() {});
    widget.child.cardController.setCard(_selCard!.jsonFileID, _selCard!.cardID, bodyNum: _selBodyNum);
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarting) return Container();

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Column(children: [

        // select file
        Row(children: [
          ElevatedButton(
              onPressed: ()=> setFileDirect(-1),
              child: const Icon( Icons.arrow_left),
          ),

          Container(width: 4),

          Expanded(child: DropdownButton<PacInfo>(
            value: _selFile,
            icon: const Icon(Icons.arrow_drop_down),
            isExpanded: true,
            onChanged: (value) {
              setSelFile(value!);
              setFirstCard();
              setSelected();
            },

            items: _fileList.map<DropdownMenuItem<PacInfo>>((fileInfo) {
              return DropdownMenuItem<PacInfo>(
                value: fileInfo,
                child: Text(fileInfo.title, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
          ) ),

          Container(width: 4),

          ElevatedButton(
            onPressed: ()=> setFileDirect(1),
            child: const Icon( Icons.arrow_right),
          ),
        ]),

        // select card
        Row(children: [
          ElevatedButton(
            onPressed: ()=> setCardDirect(-1),
            child: const Icon( Icons.arrow_left),
          ),

          Container(width: 4),

          Expanded(child: DropdownButton<CardHead>(
              value: _selCard,
              icon: const Icon(Icons.arrow_drop_down),
              isExpanded: true,

              onChanged: (value) {
                _selCard  = value!;
                _selBodyNum = 0;
                setSelected();
              },

              items: _selFileCardList.map<DropdownMenuItem<CardHead>>((cardHead) {
                return DropdownMenuItem<CardHead>(
                  value: cardHead,
                  child: Text(cardHead.title, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),

          Container(width: 4),

          ElevatedButton(
            onPressed: ()=> setCardDirect(1),
            child: const Icon( Icons.arrow_right),
          ),
        ]),

        // select body
        if (_selCard != null && _selCard!.bodyCount > 1) ...[
          Row(children: [
            ElevatedButton(
              onPressed: ()=> setBodyNumDirect(-1),
              child: const Icon( Icons.arrow_left),
            ),

            Container(width: 4),

            Expanded(child: DropdownButton<int>(
              value: _selBodyNum,
              icon: const Icon(Icons.arrow_drop_down),
              isExpanded: true,

              onChanged: (int? value) {
                _selBodyNum = value!;
                setSelected();
              },

              items: List<int>.generate(_selCard!.bodyCount, (i) => i + 1).map<DropdownMenuItem<int>>((bodyNum) {
                return DropdownMenuItem<int>(
                  value: bodyNum,
                  child: Text('${bodyNum + 1}'),
                );
              }).toList(),
            ),
            ),

            Container(width: 4),

            ElevatedButton(
              onPressed: ()=> setBodyNumDirect(1),
              child: const Icon( Icons.arrow_right),
            ),
          ]),          
        ],

        // The card is excluded from use
        if (widget.child.cardController.card != null && widget.child.cardController.card!.exclude) ...[
          Container(
            color: Colors.grey,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  Text(TextConst.txtCardExcluded),
                ],
              ),
            ),
          ),
        ],
        
      ]),
    );
  }
}
