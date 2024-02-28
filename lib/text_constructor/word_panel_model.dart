import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class JrfTextConstructor {
  static const String text               = 'text';
  static const String objects            = 'objects';
  static const String styles             = 'styles';
  static const String markStyle          = 'markStyle';
  static const String basement           = 'basement';
  static const String randomMixWord      = 'randomMixWord';
  static const String randomDelWord      = 'randomDelWord';
  static const String randomView         = 'randomView';
  static const String notDelFromBasement = 'notDelFromBasement';
  static const String canMoveWord        = 'canMoveWord';
  static const String noCursor           = 'noCursor';
  static const String focusAsCursor      = 'focusAsCursor';
  static const String answerList         = 'answerList';

  static const String fontSize           = 'fontSize';
  static const String boxHeight          = 'boxHeight';

  static const String btnKeyboard        = 'btnKeyboard';
  static const String btnUndo            = 'btnUndo';
  static const String btnRedo            = 'btnRedo';
  static const String btnBackspace       = 'btnBackspace';
  static const String btnDelete          = 'btnDelete';
  static const String btnClear           = 'btnClear';
}

class LabelInfo {
  static const String selectPrefix = '\$';

  final String label;
  late bool isSelected;
  late bool isObject;
  late int viewIndex;
  late String _word;

  bool get isText => !isObject;

  String get word {
    if (isObject) return '#$_word';
    return _word;
  }

  String get objectName {
    assert(isObject == true);
    return _word;
  }

  LabelInfo(this.label) {
    String str = label;
    if (str.startsWith(selectPrefix)) {
      isSelected = true;
      str = str.substring(1);
    } else {
      isSelected = false;
    }

    if (str.startsWith('#')){
      isObject = true;
      if (str.substring(2,3) == '|') {
        _word = str.substring(3);
        viewIndex = int.parse(str.substring(1,2));
      } else {
        _word = str.substring(1);
        viewIndex = 0;
      }
    } else {
      isObject = false;
      _word = str;
    }
  }

  static String unSelect(String label) {
    if (label.startsWith(selectPrefix)) return label.substring(1);
    return label;
  }
}

class TextInfo{
  final String string;
  late String text;
  late String image;
  late String audio;

  TextInfo(this.string) {
    String partText  = '';
    String partImage = '';
    String partAudio = '';

    final wordParts = string.split('|');
    for (var part in wordParts) {
      if (part.startsWith(JrfSpecText.imagePrefix)) {
        partImage = part.substring(JrfSpecText.imagePrefix.length);
        continue;
      }
      if (part.startsWith(JrfSpecText.audioPrefix)) {
        partAudio = part.substring(JrfSpecText.audioPrefix.length);
        continue;
      }
      partText = part;
    }

    text  = partText;
    image = partImage;
    audio = partAudio;
  }

  String getStringWith({String? text, String? image, String? audio}) {
    return getString(
      text : text??this.text,
      image: image??this.image,
      audio: audio??this.audio,
    );
  }

  static String getString({String text = '', String image = '', String audio = ''}) {
    final resList = <String>[];
    if (text.isNotEmpty) resList.add(text);
    if (image.isNotEmpty) resList.add('${JrfSpecText.imagePrefix}$image');
    if (audio.isNotEmpty) resList.add('${JrfSpecText.audioPrefix}$audio');
    return resList.join('|');
  }
}

class ViewInfo {
  static const String menuSkipText = '-';

  final String viewStr;
  late  int    styleIndex;
  late  String menuText;
  late  String text;

  bool get skipMenu => menuText == '-';

  ViewInfo(this.viewStr){
    final pos = viewStr.indexOf('|');
    if (pos == -1) {
      text       = viewStr;
      styleIndex = -1;
      menuText   = '';
    } else {
      text = viewStr.substring(pos + 1);

      final pref = viewStr.substring(0, pos);
      final viewSplit = pref.split('/');
      final styleIndexStr = viewSplit[0];
      if (styleIndexStr.isNotEmpty) {
        styleIndex = int.parse(styleIndexStr);
      } else {
        styleIndex = -1;
      }
      if (viewSplit.length > 1) {
        menuText = viewSplit[1];
      } else {
        menuText = '';
      }
    }
  }

  factory ViewInfo.fromComponents(int styleIndex, String menuText, String text) {
    return ViewInfo(getViewStr(styleIndex, menuText, text));
  }

  static String getViewStr(int styleIndex, String menuText, String text){
    return '$styleIndex/$menuText|$text';
  }

  String toJson() {
    return viewStr;
  }
}

class JrfStyleInfo {
  static const charColor       = "charColor";
  static const backgroundColor = "backgroundColor";
  static const frameColor      = "frameColor";
  static const fontBold        = "fontBold";
  static const fontItalic      = "fontItalic";
  static const linePos         = "linePos";
  static const lineStyle       = "lineStyle";
  static const lineColor       = "lineColor";
}

class StyleInfo {
  static const Map<String, Color> colorKeyMap = {
    'r' : Colors.red,
    'g' : Colors.green,
    'b' : Colors.blue,
    'y' : Colors.yellow,
    'o' : Colors.orange,
    'd' : Colors.black,
    'w' : Colors.white,
  };

  static const Map<String, String> colorNameMap = {
    'r' : 'red',
    'g' : 'green',
    'b' : 'blue',
    'y' : 'yellow',
    'o' : 'orange',
    'd' : 'black',
    'w' : 'white',
  };

  static const Map<String, TextDecoration> linePosNameMap = {
    'underline'   : TextDecoration.underline,
    'lineThrough' : TextDecoration.lineThrough,
  };

  static const Map<String, TextDecoration> _linePosKeyMap = {
    'l' : TextDecoration.underline,
    'd' : TextDecoration.lineThrough,
  };

  static const Map<String, TextDecorationStyle> _lineStyleKeyMap = {
    '_' : TextDecorationStyle.solid,
    '~' : TextDecorationStyle.wavy,
    '=' : TextDecorationStyle.double,
    '-' : TextDecorationStyle.dashed,
    '.' : TextDecorationStyle.dotted,
  };

  final bool   fontBold;
  final bool   fontItalic;
  final Color? charColor;
  final Color? backgroundColor;
  final Color? frameColor;
  final TextDecoration?      linePos;
  final TextDecorationStyle? lineStyle;
  final Color?               lineColor;

  StyleInfo({
    this.fontBold = false,
    this.fontItalic = false,
    this.charColor,
    this.backgroundColor,
    this.frameColor,
    this.linePos,
    this.lineStyle,
    this.lineColor,
  });

  factory StyleInfo.fromStyleStr(String styleStr, [int? id]) {
    bool   fontBold = false;
    bool   fontItalic = false;
    Color? charColor;
    Color? backgroundColor;
    Color? frameColor;

    TextDecoration?      linePos;
    TextDecorationStyle? lineStyle;
    Color?               lineColor;

    final subStyleList = styleStr.split(',');

    for (var subStyle in subStyleList) {
      final subStyleStr = subStyle.trim().toLowerCase();
      final subStyleLen = subStyleStr.length;

      if (subStyleLen == 1) {
        if (subStyleStr == 'b') {
          fontBold = true;
        }
        if (subStyleStr == 'i') {
          fontItalic = true;
        }
      }

      if (subStyleLen == 3) {
        final formatCh = subStyleStr.substring(0,1);
        final formatId = subStyleStr.substring(0,2);
        final colorKey = subStyleStr.substring(2,3);
        final color = colorKeyMap[colorKey];

        if (formatId == 'cc') {
          charColor = color;
        }
        if (formatId == 'bc') {
          backgroundColor = color;
        }
        if (formatId == 'fc') {
          frameColor = color;
        }

        if (formatCh == 'l') {
          linePos = TextDecoration.underline;
          final lineStyleStr = formatId.substring(1,2);
          lineStyle = _lineStyleKeyMap[lineStyleStr] ;
          lineColor  = color;
        }

        if (formatCh == 'd') {
          linePos = TextDecoration.lineThrough;
          final lineStyleStr = formatId.substring(1,2);
          lineStyle = _lineStyleKeyMap[lineStyleStr] ;
          lineColor  = color;
        }
      }
    }

    return StyleInfo(
      fontBold         : fontBold,
      fontItalic       : fontItalic,
      charColor        : charColor,
      backgroundColor  : backgroundColor,
      frameColor       : frameColor,
      linePos          : linePos,
      lineStyle        : lineStyle,
      lineColor        : lineColor,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{
      JrfStyleInfo.charColor       : colorNameMap[_colorToColorKey(charColor)],
      JrfStyleInfo.backgroundColor : colorNameMap[_colorToColorKey(backgroundColor)],
      JrfStyleInfo.frameColor      : colorNameMap[_colorToColorKey(frameColor)],
      JrfStyleInfo.fontBold        : fontBold,
      JrfStyleInfo.fontItalic      : fontItalic,
      JrfStyleInfo.linePos         : linePos?.toString().split('.').last,
      JrfStyleInfo.lineStyle       : lineStyle?.name,
      JrfStyleInfo.lineColor       : colorNameMap[_colorToColorKey(lineColor)],
    };

    return result;
  }

  factory StyleInfo.fromMap(Map<String, dynamic> map) {
    return StyleInfo(
      fontBold         : map[JrfStyleInfo.fontBold]??false,
      fontItalic       : map[JrfStyleInfo.fontItalic]??false,
      charColor        : colorNameToColor(map[JrfStyleInfo.charColor]),
      backgroundColor  : colorNameToColor(map[JrfStyleInfo.backgroundColor]),
      frameColor       : colorNameToColor(map[JrfStyleInfo.frameColor]),
      linePos          : linePosNameMap[map[JrfStyleInfo.linePos]],
      lineStyle        : TextDecorationStyle.values.firstWhereOrNull((lineStyle) => lineStyle.name == map[JrfStyleInfo.lineStyle]),
      lineColor        : colorNameToColor(map[JrfStyleInfo.lineColor]),
    );
  }

  static Color colorNameToColor(String? colorName) {
    if (colorName == null) return Colors.transparent;
    final colorKey = colorNameMap.entries.firstWhereOrNull((entry) => entry.value == colorName)?.key;
    if (colorKey == null) return Colors.transparent;
    return colorKeyMap[colorKey]!;
  }

  @override
  String toString() {
    final subStyleList = <String>[];

    if (fontBold) {
      subStyleList.add('b');
    }

    if (fontItalic) {
      subStyleList.add('i');
    }

    if (charColor != null) {
      subStyleList.add('cc${_colorToColorKey(charColor!)}');
    }

    if (backgroundColor != null) {
      subStyleList.add('bc${_colorToColorKey(backgroundColor!)}');
    }

    if (frameColor != null) {
      subStyleList.add('fc${_colorToColorKey(frameColor!)}');
    }

    if (linePos != null) {
      final linePosStr   = _linePosKeyMap.entries.firstWhereOrNull((entry) => entry.value == linePos)?.key;
      final lineStyleStr = _lineStyleKeyMap.entries.firstWhereOrNull((entry) => entry.value == lineStyle)?.key;
      final lineColorStr = _colorToColorKey(lineColor!);
      subStyleList.add('$linePosStr$lineStyleStr$lineColorStr');
    }


    return subStyleList.join(',');
  }

  String? _colorToColorKey(Color? color) {
    if (color == null) return null;
    return colorKeyMap.entries.firstWhereOrNull((entry) => entry.value == color)?.key;
  }

  String toJson() {
    return toString();
  }
}

class JrfSpecText {
  static const String imagePrefix  = "img="; // Prefix for box image: img=<file path>
  static const String audioPrefix  = "audio="; // Prefix for box image: img=<file path>
  static const String wordKeyboard = '@keyboard'; // box with Keyboard icon, call input text dialog
  static const String hideMenuItem = '-'; // Special text for popup menu item, it is hide this menu item from menu
}

class JrfWordObject {
  static const String name         = 'name';
  static const String nonRemovable = 'nonRemovable';
  static const String views        = 'views';
}

class TextConstructorData {
  String text;
  final List<WordObject> objects;
  final List<StyleInfo> styles;
  int markStyle;
  String basement;

  bool canMoveWord;
  bool randomMixWord;
  bool randomDelWord;
  bool randomView;
  bool notDelFromBasement;
  bool noCursor;
  bool focusAsCursor;

  final List<String>? answerList;

  double fontSize ;
  double boxHeight;

  bool btnKeyboard ;
  bool btnUndo     ;
  bool btnRedo     ;
  bool btnBackspace;
  bool btnDelete   ;
  bool btnClear    ;

  TextConstructorData({
    required this.text,
    required this.objects,
    required this.styles,
    this.markStyle = -1,
    this.basement = '',
    this.randomMixWord = false,
    this.randomDelWord = false,
    this.randomView = false,
    this.notDelFromBasement = false,
    this.canMoveWord   = true,
    this.noCursor      = false,
    this.focusAsCursor = true,
    this.answerList,

    this.fontSize     = 40.0,
    this.boxHeight    = 0.0,

    this.btnKeyboard  = true,
    this.btnUndo      = true,
    this.btnRedo      = true,
    this.btnBackspace = true,
    this.btnDelete    = true,
    this.btnClear     = true,
  });

  void setFromMap(Map<String, dynamic> jsonMap) {
    for (var entry in jsonMap.entries) {
      if (entry.value == null) continue;

      if (entry.key == JrfTextConstructor.text              ) text               = entry.value??'';
      if (entry.key == JrfTextConstructor.markStyle         ) markStyle          = entry.value??-1;
      if (entry.key == JrfTextConstructor.basement          ) basement           = entry.value??'';
      if (entry.key == JrfTextConstructor.randomMixWord     ) randomMixWord      = entry.value??false;
      if (entry.key == JrfTextConstructor.randomDelWord     ) randomDelWord      = entry.value??false;
      if (entry.key == JrfTextConstructor.randomView        ) randomView         = entry.value??false;
      if (entry.key == JrfTextConstructor.notDelFromBasement) notDelFromBasement = entry.value??false;
      if (entry.key == JrfTextConstructor.canMoveWord       ) canMoveWord        = entry.value??true;
      if (entry.key == JrfTextConstructor.noCursor          ) noCursor           = entry.value??false;
      if (entry.key == JrfTextConstructor.focusAsCursor     ) focusAsCursor      = entry.value??true;
      if (entry.key == JrfTextConstructor.fontSize          ) fontSize           = entry.value??40.0;
      if (entry.key == JrfTextConstructor.boxHeight         ) boxHeight          = entry.value??0.0;
      if (entry.key == JrfTextConstructor.btnKeyboard       ) btnKeyboard        = entry.value??true;
      if (entry.key == JrfTextConstructor.btnUndo           ) btnUndo            = entry.value??true;
      if (entry.key == JrfTextConstructor.btnRedo           ) btnRedo            = entry.value??true;
      if (entry.key == JrfTextConstructor.btnBackspace      ) btnBackspace       = entry.value??true;
      if (entry.key == JrfTextConstructor.btnDelete         ) btnDelete          = entry.value??true;
      if (entry.key == JrfTextConstructor.btnClear          ) btnClear           = entry.value??true;
    }
  }

  factory TextConstructorData.fromMap(Map<String, dynamic> json) {
    return TextConstructorData(
      text               : json[JrfTextConstructor.text]??'',
      objects            : objectListFromMapList<WordObject>(WordObject.fromMap, json[JrfTextConstructor.objects]),
      styles             : dynamicList(json[JrfTextConstructor.styles]).mapIndexed ((index, value) => StyleInfo.fromStyleStr(value, index)).toList(),
      markStyle          : json[JrfTextConstructor.markStyle]??-1,
      basement           : json[JrfTextConstructor.basement]??'',
      randomMixWord      : json[JrfTextConstructor.randomMixWord]??false,
      randomDelWord      : json[JrfTextConstructor.randomDelWord]??false,
      randomView         : json[JrfTextConstructor.randomView]??false,
      notDelFromBasement : json[JrfTextConstructor.notDelFromBasement]??false,
      canMoveWord        : json[JrfTextConstructor.canMoveWord]??true,
      noCursor           : json[JrfTextConstructor.noCursor]??false,
      focusAsCursor      : json[JrfTextConstructor.focusAsCursor]??true,
      answerList         : valueListFromMapList<String>(json[JrfTextConstructor.answerList]),

      fontSize           : json[JrfTextConstructor.fontSize]??40.0,
      boxHeight          : json[JrfTextConstructor.boxHeight]??0.0,

      btnKeyboard        : json[JrfTextConstructor.btnKeyboard ]??true,
      btnUndo            : json[JrfTextConstructor.btnUndo     ]??true,
      btnRedo            : json[JrfTextConstructor.btnRedo     ]??true,
      btnBackspace       : json[JrfTextConstructor.btnBackspace]??true,
      btnDelete          : json[JrfTextConstructor.btnDelete   ]??true,
      btnClear           : json[JrfTextConstructor.btnClear    ]??true,

    );
  }

  Map<String, dynamic> toJson() => {
    JrfTextConstructor.text               :text,
    JrfTextConstructor.objects            :objects.map((object) => object.toJson()).toList(),
    JrfTextConstructor.styles             :styles,
    JrfTextConstructor.markStyle          :markStyle,
    JrfTextConstructor.basement           :basement,
    JrfTextConstructor.randomMixWord      :randomMixWord,
    JrfTextConstructor.randomDelWord      :randomDelWord,
    JrfTextConstructor.randomView         :randomView,
    JrfTextConstructor.notDelFromBasement :notDelFromBasement,
    JrfTextConstructor.canMoveWord        :canMoveWord,
    JrfTextConstructor.noCursor           :noCursor,
    JrfTextConstructor.focusAsCursor      :focusAsCursor,
    JrfTextConstructor.answerList         :answerList,

    JrfTextConstructor.fontSize           :fontSize,
    JrfTextConstructor.boxHeight          :boxHeight,

    JrfTextConstructor.btnKeyboard        :btnKeyboard ,
    JrfTextConstructor.btnUndo            :btnUndo     ,
    JrfTextConstructor.btnRedo            :btnRedo     ,
    JrfTextConstructor.btnBackspace       :btnBackspace,
    JrfTextConstructor.btnDelete          :btnDelete   ,
    JrfTextConstructor.btnClear           :btnClear    ,
  };
}

class WordObject {
  final String name;
  final bool nonRemovable;
  final List<ViewInfo> views;

  WordObject({
    required this.name,
    required this.nonRemovable,
    required this.views
  });

  factory WordObject.fromMap(Map<String, dynamic> json) {
    return WordObject(
      name         : json[JrfWordObject.name],
      nonRemovable : json[JrfWordObject.nonRemovable]??false,
      views        : dynamicList(json[JrfWordObject.views]).map((value) => ViewInfo(value)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    JrfWordObject.name         :name,
    JrfWordObject.nonRemovable :nonRemovable,
    JrfWordObject.views        :views,
  };
}

List<dynamic> dynamicList(dynamic value) {
  if (value == null) return [];
  assert(value is List);
  return value as List<dynamic>;
}

List<T> valueListFromMapList<T>(dynamic value) {
  if (value == null) return [];
  if (value is! List) return [];
  return List<T>.from(value.map((t) => t));
}

typedef CreateFromMap<T> = T Function(Map<String, dynamic>);

List<T> objectListFromMapList<T>(CreateFromMap<T> createFromMap, dynamic value) {
  if (value == null) return [];
  if (value is! List) return [];

  return List<T>.from(value.map((tMap) => createFromMap.call(tMap) ));
}
