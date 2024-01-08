import 'package:collection/collection.dart';
import 'db.dart';
import 'package:flutter/material.dart';

import 'card_controller.dart';
import 'card_model.dart';
import 'package:simple_events/simple_events.dart' as event;

import 'dk_expansion_tile.dart';

class CardNavigatorData {
  DbSource dbSource;

  final fileList = <PacInfo>[];
  final cardList = <CardHead>[];

  CardNavigatorData(this.dbSource);

  final onChange = event.SimpleEvent();

  Future<void> setData() async {
    final fileRows = await dbSource.tabJsonFile.getAllRows();
    if (fileRows.isEmpty) return;

    fileList.clear();
    fileList.addAll( fileRows.map((row) => PacInfo.fromMap(row)).toList() );

    fileList.sort((a, b) => a.jsonFileID.compareTo(b.jsonFileID));

    final cardRows = await dbSource.tabCardHead.getAllRows();
    if (cardRows.isEmpty) return;

    cardList.clear();
    cardList.addAll( cardRows.map((row) => CardHead.fromMap(row)).toList() );
    cardList.sort((a, b) => a.cardID.compareTo(b.cardID));

    onChange.send();
  }

  void sendChanged() {
    onChange.send();
  }
}

enum NavigatorMode{
  multiPack,
  singlePack,
  noPackHead
}

class CardNavigator extends StatefulWidget {
  final CardController cardController;
  final CardNavigatorData cardNavigatorData;
  final NavigatorMode mode;

  const CardNavigator({
    required this.cardController,
    required this.cardNavigatorData,
    this.mode = NavigatorMode.multiPack,

    Key? key
  }) : super(key: key);

  @override
  State<CardNavigator> createState() => _CardNavigatorState();
}

class _CardNavigatorState extends State<CardNavigator> {
  List<PacInfo> get _fileList => widget.cardNavigatorData.fileList;
  List<CardHead> get _cardList => widget.cardNavigatorData.cardList;

  PacInfo? _selFile;
  final _selFileCardList = <CardHead>[];
  CardHead? _selCard;
  int _selBodyNum = 0;

  event.Listener? _cardControllerOnChangeListener;

  @override
  void initState() {
    super.initState();

    _cardControllerOnChangeListener = widget.cardController.onChange.subscribe((listener, data) {
      onChange();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange();
    });
  }

  void onChange() {
    if (!mounted) return;

    if (_selFile == null || _selFile!.jsonFileID != widget.cardController.card!.pacInfo.jsonFileID) {
      final file =  _fileList.firstWhereOrNull((file) => file.jsonFileID == widget.cardController.card!.pacInfo.jsonFileID);
      if (file ==null) return;

      setSelFile(file);
    }

    if (_selCard == null || _selCard!.jsonFileID != widget.cardController.card!.head.jsonFileID || _selCard!.cardID != widget.cardController.card!.head.cardID) {
      _selCard = _selFileCardList.firstWhere((card) => card.cardID == widget.cardController.card!.head.cardID);
    }

    _selBodyNum = widget.cardController.card!.body.bodyNum;
    setState(() {});
  }

  @override
  void dispose() {
    _cardControllerOnChangeListener?.dispose();
    super.dispose();
  }

  void setSelFile(PacInfo file){
    if (_selFile == file) return;

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

  void setSelected() async {
    await widget.cardController.setCard(_selCard!.jsonFileID, _selCard!.cardID, bodyNum: _selBodyNum);
  }

  @override
  Widget build(BuildContext context) {
    if (_selCard == null) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Column(children: [

        if (widget.mode == NavigatorMode.multiPack && _fileList.length > 1) ...[
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
        ],

        // file header
        if (widget.mode == NavigatorMode.singlePack || (widget.mode == NavigatorMode.multiPack && _fileList.length == 1)) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_selFile!.title),
          )
        ],

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

              items: List<int>.generate(_selCard!.bodyCount, (i) => i).map<DropdownMenuItem<int>>((bodyNum) {
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
        ]
      ]),
    );
  }
}

class _TreeParam {
  final Color itemTextColor;
  final Color selItemTextColor;
  final Color bodyButtonColor;

  _TreeParam({required this.itemTextColor, required this.selItemTextColor, required this.bodyButtonColor});
}

class CardNavigatorTree extends StatefulWidget {
  final CardController cardController;
  final CardNavigatorData cardNavigatorData;
  final Color itemTextColor;
  final Color selItemTextColor;
  final Color bodyButtonColor;
  final NavigatorMode mode;

  const CardNavigatorTree({
    required this.cardController,
    required this.cardNavigatorData,
    required this.itemTextColor,
    required this.selItemTextColor,
    required this.bodyButtonColor,
    this.mode = NavigatorMode.multiPack,

    Key? key
  }) : super(key: key);

  @override
  State<CardNavigatorTree> createState() => _CardNavigatorTreeState();
}

class _CardNavigatorTreeState extends State<CardNavigatorTree> {
  late _TreeParam _treeParam;
  final _scrollController = ScrollController();

  event.Listener? _cardNavigatorDataListener;

  @override
  void initState() {
    super.initState();

    _treeParam = _TreeParam(itemTextColor: widget.itemTextColor, selItemTextColor: widget.selItemTextColor, bodyButtonColor: widget.bodyButtonColor);
    _cardNavigatorDataListener = widget.cardNavigatorData.onChange.subscribe((listener, data) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cardNavigatorDataListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cardController.card == null) {
      return Container();
    }

    if (widget.mode == NavigatorMode.singlePack || widget.mode == NavigatorMode.noPackHead) {
      final file = widget.cardNavigatorData.fileList.firstWhere((file) => file.jsonFileID == widget.cardController.card!.head.jsonFileID);
      final cardList = widget.cardNavigatorData.cardList.where((card) => card.jsonFileID == file.jsonFileID).toList();

      return Scrollbar(
        thumbVisibility: true,
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: _TreeFileWidget(
            cardController: widget.cardController,
            jsonFileID: file.jsonFileID,
            title: file.title,
            cardList: cardList,
            treeParam: _treeParam,
            noFileHead: widget.mode == NavigatorMode.noPackHead,
          )
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      controller: _scrollController,
      child: ListView.builder (
        controller: _scrollController,
        itemCount: widget.cardNavigatorData.fileList.length,
        itemBuilder: (BuildContext context, int index) {
          final file = widget.cardNavigatorData.fileList[index];
          final cardList = widget.cardNavigatorData.cardList.where((card) => card.jsonFileID == file.jsonFileID).toList();

          return _TreeFileWidget(
            cardController: widget.cardController,
            jsonFileID: file.jsonFileID,
            title: file.title,
            cardList: cardList,
            treeParam: _treeParam,
          );
        },
      ),
    );

  }
}

class _TreeFileWidget extends StatefulWidget {
  final CardController cardController;
  final int jsonFileID;
  final String title;
  final List<CardHead> cardList;
  final _TreeParam treeParam;
  final bool noFileHead;

  const _TreeFileWidget({required this.cardController, required this.jsonFileID, required this.title, required this.cardList, required this.treeParam, this.noFileHead = false, Key? key}) : super(key: key);

  @override
  State<_TreeFileWidget> createState() => _TreeFileWidgetState();
}

class _TreeFileWidgetState extends State<_TreeFileWidget> {
  bool _isSelected = false;

  late event.Listener cardControllerOnChangeListener;

  final _controller = DkExpansionTileController();

  @override
  void initState() {
    super.initState();

    cardControllerOnChangeListener = widget.cardController.onChange.subscribe((listener, data) {
      onChange();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange();
    });
  }

  void onChange() {
    if (!mounted) return;
    if (widget.cardController.card == null) return;

    final isSelected = widget.cardController.card!.head.jsonFileID == widget.jsonFileID;

    if (_isSelected != isSelected) {
      setState(() {
        _isSelected = isSelected;

      });

      if (isSelected) {
        if (_controller.isAssigned) {
          _controller.expand();
        }
      }
    }
  }

  @override
  void dispose() {
    cardControllerOnChangeListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _isSelected? widget.treeParam.selItemTextColor : widget.treeParam.itemTextColor;

    final groupMap = <String, List<CardHead>? >{};

    for (var card in widget.cardList) {
      if (card.group.isNotEmpty) {
        final cardList = groupMap[card.group];
        if (cardList == null) {
          groupMap[card.group] = [card];
          continue;
        }
        cardList.add(card);
      }
    }

    final children = <Widget>[];

    for (var card in widget.cardList) {
      if (card.jsonFileID != widget.jsonFileID) continue;

      if (card.group.isEmpty) {
        children.add( _TreeCardWidget(cardController: widget.cardController, card: card, treeParam: widget.treeParam) );
        continue;
      }

      final cardList = groupMap[card.group];
      if (cardList == null) continue;

      // comment this for debug
      if (cardList.length == 1) {
        children.add( _TreeCardWidget(cardController: widget.cardController, card: card, treeParam: widget.treeParam) );
        continue;
      }

      children.add( _TreeGroupWidget(
        cardController: widget.cardController,
        group: card.group,
        cardList: cardList,
        treeParam: widget.treeParam,
      ));

      groupMap[card.group] = null;
    }

    if (widget.noFileHead) {
      return Column(children: children);
    }

    return DkExpansionTile(
      controller: _controller,
      title: Text(widget.title, style: TextStyle(color: color)),
      initiallyExpanded: false,
      children: children,
    );
  }
}


class _TreeCardWidget extends StatefulWidget {
  final CardController cardController;
  final CardHead card;
  final _TreeParam treeParam;
  const _TreeCardWidget({required this.cardController, required this.card, required this.treeParam, Key? key}) : super(key: key);

  @override
  State<_TreeCardWidget> createState() => _TreeCardWidgetState();
}

class _TreeCardWidgetState extends State<_TreeCardWidget> {
  bool _isSelected = false;
  int _selBodyNum = 0;

  late event.Listener cardControllerOnChangeListener;

  final _controller = DkExpansionTileController();

  @override
  void initState() {
    super.initState();

    cardControllerOnChangeListener = widget.cardController.onChange.subscribe((listener, data) {
      onChange();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange();
    });
  }

  void onChange() {
    if (!mounted) return;
    if (widget.cardController.card == null) return;

    if (widget.cardController.card!.head.cardID == widget.card.cardID) {
      if (!_isSelected || _selBodyNum != widget.cardController.card!.body.bodyNum) {
        setState(() {
          _isSelected = true;
          _selBodyNum = widget.cardController.card!.body.bodyNum;
        });

        if (_controller.isAssigned) {
          _controller.expand();
        }

        return;
      }
    }

    if (_isSelected) {
      setState(() {
        _isSelected = false;
      });
      return;
    }
  }

  @override
  void dispose() {
    cardControllerOnChangeListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _isSelected? widget.treeParam.selItemTextColor : widget.treeParam.itemTextColor;

    // comment this for debug
    if (widget.card.bodyCount == 1) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ListTile(
          title: Text(widget.card.title, style: TextStyle(color: color)),
          onTap: (){
            widget.cardController.setCard(widget.card.jsonFileID, widget.card.cardID, bodyNum: 0);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: DkExpansionTile(
        controller: _controller,
        title: Text(widget.card.title, style: TextStyle(color: color)),
        initiallyExpanded: false,
        children: [Align(
          alignment: Alignment.topLeft,
          child: Wrap(
              children: List.generate(widget.card.bodyCount, (bodyNum) {
                final isSelBody = _isSelected && bodyNum == _selBodyNum;
                final color = isSelBody? widget.treeParam.selItemTextColor : widget.treeParam.bodyButtonColor;

                return ElevatedButton(
                  onPressed: () {
                    widget.cardController.setCard(widget.card.jsonFileID, widget.card.cardID, bodyNum: bodyNum);
                  },
                  style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                      backgroundColor: color
                  ),
                  child: Text(bodyNum.toString(), style: const TextStyle(color: Colors.black)),
                );

              })
          ),
        )],
      ),
    );
  }
}

class _TreeGroupWidget extends StatefulWidget {
  final CardController cardController;
  final String group;
  final List<CardHead> cardList;
  final _TreeParam treeParam;
  const _TreeGroupWidget({required this.cardController, required this.group, required this.cardList, required this.treeParam, Key? key}) : super(key: key);

  @override
  State<_TreeGroupWidget> createState() => _TreeGroupWidgetState();
}

class _TreeGroupWidgetState extends State<_TreeGroupWidget> {
  bool _isSelected = false;

  late event.Listener cardControllerOnChangeListener;

  final _controller = DkExpansionTileController();

  @override
  void initState() {
    super.initState();

    cardControllerOnChangeListener = widget.cardController.onChange.subscribe((listener, data) {
      onChange();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange();
    });
  }

  void onChange() {
    if (!mounted) return;
    if (widget.cardController.card == null) return;

    final isSelected = widget.cardList.any((card) => card.cardID == widget.cardController.card!.head.cardID);

    if (_isSelected != isSelected) {
      setState(() {
        _isSelected = isSelected;
      });

      if (isSelected) {
        if (_controller.isAssigned) {
          _controller.expand();
        }
      }
    }
  }

  @override
  void dispose() {
    cardControllerOnChangeListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _isSelected? widget.treeParam.selItemTextColor : widget.treeParam.itemTextColor;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: DkExpansionTile(
        controller: _controller,
        title: Text(widget.group, style: TextStyle(color: color)),
        initiallyExpanded: false,
        children: widget.cardList.map((card) => _TreeCardWidget(cardController: widget.cardController, card: card, treeParam: widget.treeParam)).toList(),
      ),
    );
  }
}

