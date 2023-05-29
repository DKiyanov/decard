enum FileSourceType {
  localPath,
  webDAV,
}

class FileSource {
  final FileSourceType type;
  final String url;
  final String? subPath;
  final String? login;
  final String? password;

  String? _localPath;
  String get localPath {
    if (type == FileSourceType.localPath) return url;
    return _localPath??'';
  }
  set localPath(String value) {
    if (type != FileSourceType.localPath) _localPath = value;
  }

  FileSource({
    required this.type,
    required this.url,
    this.subPath,
    this.login,
    this.password,
    String? localPath
  }) {
    _localPath = localPath;
  }

  @override
  String toString() {
    if (subPath == null || subPath!.isEmpty) {
      return url;
    }

    return '$url/$subPath';
  }

  factory FileSource.fromJson(Map<String, dynamic> json) {
    final String typeStr = json["type"];

    return FileSource(
      type      : FileSourceType.values.firstWhere((x) => x.name == typeStr),
      url       : json["url"],
      subPath   : json["subPath"],
      login     : json["login"],
      password  : json["password"],
      localPath : json["localPath"],
    );
  }

  Map<String, dynamic> toJson() => {
    "type"      : type.name,
    "url"       : url,
    "subPath"   : subPath,
    "login"     : login,
    "password"  : password,
    "localPath" : _localPath,
  };
}