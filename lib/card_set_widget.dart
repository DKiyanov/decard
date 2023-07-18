import 'package:decard/regulator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'card_model.dart';
import 'common.dart';

typedef NewCardSet = void Function(RegCardSet newObject);

class CardSetWidget extends StatefulWidget {
  final RegCardSet cardSet;
  final bool editing;
  final bool showDelButton;

  final List<String> allCardList;
  final List<String> allGroupList;
  final List<String> allTagList;
  final List<String> allDifficulties;

  final List<String> selTagList;

  final NewCardSet   onChange;
  final VoidCallback onCancelEditing;
  final VoidCallback onDelete;

  const CardSetWidget({
    required this.cardSet,
    this.editing = false,
    this.showDelButton = false,
    required this.allCardList,
    required this.allGroupList,
    required this.allTagList,
    required this.allDifficulties,
    required this.selTagList,
    required this.onChange,
    required this.onCancelEditing,
    required this.onDelete,
    Key? key
  }) : super(key: key);

  @override
  State<CardSetWidget> createState() => _CardSetWidgetState();
}

class _CardSetWidgetState extends State<CardSetWidget> {
  static const String _nullDifficultyStr = '-';

  bool _editing = false;

  final _cards        = <String>[]; // array of cardID or mask
  final _groups       = <String>[]; // array of cards group or mask
  final _tags         = <String>[]; // array of tags
  final _andTags      = <String>[]; // array of tags join trough and
  final _difficulties = <String>[]; // array of difficulty levels

  bool   _exclude    = false; // bool - exclude card from studying
  String _difficulty = _nullDifficultyStr;    // int - difficulty level

  @override
  void initState() {
    super.initState();

    _editing = widget.editing;

    init(widget.cardSet);
  }

  void init(RegCardSet cardSet){
    _cards.clear();
    _groups.clear();
    _tags.clear();
    _andTags.clear();
    _difficulties.clear();

    _cards.addAll(cardSet.cards??[]);
    _groups.addAll(cardSet.groups??[]);
    _tags.addAll(cardSet.tags??[]);
    _andTags.addAll(cardSet.andTags??[]);
    _difficulties.addAll((cardSet.difficultyLevels??[]).map((level) => level.toString()).toList());

    _exclude = cardSet.exclude;

    if (cardSet.difficultyLevel != null) {
      _difficulty = cardSet.difficultyLevel!.toString();
    } else {
      _difficulty = _nullDifficultyStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing ) return _body();

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              setState(() {
                _editing = true;
              });
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: TextConst.txtEdit,
          ),
        ],
      ),

      child: _body(),
    );
  }

  Widget _body() {
    final ddDifficulties = List.from(widget.allDifficulties);
    ddDifficulties.insert(0, _nullDifficultyStr);

    return Column(children: [
      _tagList(TextConst.drfCardSetCards  , _cards       , widget.allCardList  , TagPrefix.cardKey),
      _tagList(TextConst.drfCardSetGroups , _groups      , widget.allGroupList , TagPrefix.group),
      _tagList(TextConst.drfCardSetTags   , _tags        , widget.allTagList),
      _tagList(TextConst.drfCardSetAndTags, _andTags     , widget.allTagList),
      _tagList(TextConst.drfDifficulties  , _difficulties, widget.allDifficulties, TagPrefix.difficulty),

      Card(
        child: Column(
          children: [

            // Exclude
            if ((!_editing && _exclude) || _editing) ...[
              Row(children: [
                Container(width: 6),
                Expanded(child: Text(TextConst.drfExclude)),
                Expanded(
                  child: Align(
                    child: Switch(
                        value: _exclude,
                        onChanged: !_editing? null : (value){
                          setState(() {
                            _exclude = value;
                          });
                        }
                    ),
                  ),
                ),
              ]),
            ],

            // DifficultyLevel
            if ((!_editing && _difficulty != _nullDifficultyStr) || _editing) ...[
              Row(children: [
                Container(width: 6),
                Expanded(child: Text(TextConst.drfDifficulty)),
                Expanded(
                  child: Align(
                    child: !_editing? Text(_difficulty) :
                    DropdownButton<String>(
                      value: _difficulty,
                      icon: const Icon(Icons.arrow_drop_down),
                      onChanged: (value) {
                        setState(() {
                          _difficulty = value ?? _nullDifficultyStr;
                        });
                      },
                      items: ddDifficulties.map((difficulty) => DropdownMenuItem<String>(
                        value: difficulty,
                        child: Text(difficulty),
                      )).toList(),
                    ),
                  ),
                )
              ]),
            ],

          ],
        ),
      ),

      if (_editing) ...[
        Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.deepOrangeAccent), onPressed: () {
                setState(() {
                  _editing = false;
                  init(widget.cardSet);
                  widget.onCancelEditing.call();
                });
              }),

              if (widget.showDelButton) ...[
                IconButton(icon: const Icon(Icons.delete, color: Colors.blue), onPressed: (){
                  widget.onDelete();
                }),
              ],

              IconButton(icon: const Icon(Icons.check, color: Colors.lightGreen), onPressed: () {
                final newCardSet = RegCardSet(
                  fileGUID         : widget.cardSet.fileGUID,
                  cards            : _cards,
                  groups           : _groups,
                  tags             : _tags,
                  andTags          : _andTags,
                  difficultyLevels : _difficulties.map((levelStr) => int.parse(levelStr)).toList(),
                  exclude          : _exclude,
                  difficultyLevel  : _difficulty == _nullDifficultyStr ? null: int.parse(_difficulty),
                );

                widget.onChange.call(newCardSet);

                setState(() {
                  _editing = false;
                });
              }),
            ])
      ]
    ]);
  }

  Widget _tagList(String title, List<String> tags, List<String> allTags, [String prefix = '']) {
    if (allTags.isEmpty) return Container();
    if (!_editing && tags.isEmpty) return Container();

    final chipList = tags.map((tag) => Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Chip(
        label: Text(tag),
        backgroundColor: widget.selTagList.contains('$prefix$tag')? Colors.yellow : null,
        onDeleted: !_editing? null : () {
          setState(() {
            tags.remove(tag);
          });
        },
      ),
    )).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(children: [
          Container(width: 4),
          Expanded(child: Text(title)),
          Expanded(child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.all(Radius.circular(5))
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 2, right: 2),
                child: Wrap(children: chipList),
              )
          )),

          if (_editing) ...[
            PopupMenuButton<String>(
              icon: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white)
              ),
              itemBuilder: (context) {
                return allTags.where((tag) => !tags.contains(tag)).map<PopupMenuItem<String>>((menuTag) => PopupMenuItem<String>(
                  value: menuTag,
                  child: Container(color: widget.selTagList.contains('$prefix$menuTag')? Colors.yellow : null, child: Text(menuTag)),
                )).toList();
              },
              onSelected: (value){
                setState(() {
                  tags.add(value);
                });
              },
            )
          ]
        ]),
      ),
    );
  }

}