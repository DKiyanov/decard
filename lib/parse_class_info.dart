class ParseObjectField {
  static const String objectID   = 'objectId';
}

class ParseWebPackUpload {
  static const String className = 'UploadWebFile';

  static const String userID    = 'UserID';
  static const String fileName  = 'FileName';
  static const String size      = 'Size';
  static const String content   = 'Content';
}

class ParseWebPackHead {
  static const String className    = 'DecardFileHead';

  static const String packId       = 'packID';
  static const String content      = 'Content';
  static const String fileName     = 'FileName';
  static const String fileSize     = 'FileSize';
  static const String createdAt    = 'createdAt';
  static const String publicationMoment = 'PublicationMoment';
  static const String starsCount   = 'StarsCount';
  static const String userID       = 'UserID';
}

class ParseWebPackSubFile {
  static const String className    = 'DecardFileSub';

  static const String packId       = 'packID';
  static const String file         = 'file';
  static const String path         = 'path';
  static const String isText       = 'isText';
  static const String textContent  = 'textContent';
}

class ParseWebPackUserFiles {
  static const String className    = 'DecardUserFiles';

  static const String userID       = 'UserID';
  static const String packId       = 'packID';
}

class ParseChild {
  static const String className  = 'Child';

  static const String userID     = 'UserID';
  static const String name       = 'Name';
}

class ParseDevice {
  static const String className  = 'Device';

  static const String userID     = 'UserID';
  static const String childID    = 'ChildID';
  static const String name       = 'Name';
  static const String deviceOSID = 'DeviceOSID';
}

class ParseWebChildSource {
  static const String className   = 'DecardFile';
  static const String userID      = 'UserID';
  static const String path        = 'Path';
  static const String fileName    = 'FileName';
  static const String size        = 'Size';
  static const String content     = 'Content';

  static const String textContent = 'TextContent';
  static const String addInfo     = 'AddInfo';
  static const String sourceType  = 'SourceType';

  static const String sourceTypePack      = 'pack';
  static const String sourceTypeRegulator = 'regulator';
}

class ParseTestResult {
  static const String className = 'DecardTestResult';

  static const String userID    = 'UserID';
  static const String childID   = 'ChildID';
  static const String dateTime  = 'dateTime';
}

class ParseDecardStat {
  static const String className = 'DecardStat';

  static const String userID    = 'UserID';
  static const String childID   = 'ChildID';
  static const String fileGuid  = 'FileGuid';
  static const String cardID    = 'cardID';
}

class ParseInvite {
  static const String className = 'Invite';

  static const String forWhom        = 'for';
  static const String expirationTime = 'expirationTime';
  static const String userID         = 'userID';
  static const String inviteKey      = 'inviteKey';
}