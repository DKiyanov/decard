import 'db_flt.dart';
import 'regulator.dart';
import 'db.dart';

final dbAddInitialized = _init();

bool _init() {
  Regulator.applySetItemToDB = applySetItemToDB;
  return true;
}

Future<void> applySetItemToDB(DbSource dbSource, RegCardSet set, int setIndex) async {
  final jsonFileID = dbSource.tabJsonFile.fileGuidToJsonFileId(set.fileGUID);

  if (jsonFileID == null) return;

  final andList = <String>[];
  final arguments = <Object>[];

  if (set.cards!.isNotEmpty) {
    andList.add('${TabCardHead.tabName}.${TabCardHead.kCardKey} IN (${set.cards!.map((_) => '?').join(', ')})');
    arguments.addAll(set.cards!);
  }

  if (set.groups!.isNotEmpty) {
    andList.add('${TabCardHead.tabName}.${TabCardHead.kGroup} IN (${set.groups!.map((_) => '?').join(', ')})');
    arguments.addAll(set.groups!);
  }

  if (set.tags!.isNotEmpty) {
    final subSql = '''EXISTS ( SELECT 1
        FROM ${TabCardTag.tabName} as tags
       WHERE tags.${TabCardTag.kCardID} = ${TabCardHead.tabName}.${TabCardHead.kCardID}
         AND tags.${TabCardTag.kTag} IN (${set.tags!.map((_) => '?').join(', ')}) 
      )
      ''';

    andList.add(subSql);
    arguments.addAll(set.tags!);
  }

  if (set.andTags!.isNotEmpty) {
    // it is checked that all the requested tags are present in the row
    final subSql = '''EXISTS (SELECT 1
        FROM ( 
            SELECT COUNT(*) as cnt
              FROM ${TabCardTag.tabName} as tags
             WHERE tags.${TabCardTag.kCardID} = ${TabCardHead.tabName}.${TabCardHead.kCardID}
               AND tags.${TabCardTag.kTag} IN (${set.andTags!.map((_) => '?').join(', ')}) 
        ) as sub
       WHERE sub.cnt = ?
      ''';

    andList.add(subSql);
    arguments.addAll(set.andTags!);
    arguments.add(set.andTags!.length);
  }

  var andWhere = '';

  if (andList.isNotEmpty) {
    andWhere = 'AND ${andList.join(' AND ')}';
  }

  final sql = '''SELECT
    ${TabCardHead.tabName}.${TabCardHead.kJsonFileID}, 
    ${TabCardHead.tabName}.${TabCardHead.kCardID}
      FROM ${TabCardHead.tabName}
     WHERE ${TabCardHead.kJsonFileID} = $jsonFileID
      $andWhere  
    ''';

  final rows = await (dbSource as DbSourceFlt).db.rawQuery(sql, arguments);

  for (var row in rows) {
    final jsonFileID = row.values.first as int;
    final cardID = row.values.last as int;
    dbSource.tabCardHead.setRegulatorPatchOnCard(
      jsonFileID        : jsonFileID,
      cardID            : cardID,
      exclude           : set.exclude,
      regulatorSetIndex : setIndex,
    );
  }
}