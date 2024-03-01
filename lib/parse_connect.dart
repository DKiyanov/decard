import 'package:parse_server_sdk_flutter/parse_server_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_events/simple_events.dart' as event;
import 'common.dart';
import 'login_invite.dart';

class ParseConnect {
  static const String _applicationId   = 'dk_parental_control';
  static const String _keyServerURL    = 'ServerURL';
  static const String _keyIsAnonymous  = 'isAnonymous';

  ParseConnect(this._prefs);

  final SharedPreferences _prefs;

  String _serverURL = '';
  String get serverURL => _serverURL;

  String _loginId = '';
  String get loginId => _loginId;

  ParseUser? _user;
  ParseUser? get user => _user;

  bool get isLoggedIn => _user != null;

  bool _isAnonymous = false;
  bool get isAnonymous => _isAnonymous;

  String _lastError = '';
  String get lastError => _lastError;

  final onLoggedInChange = event.SimpleEvent();

  Future<void> init() async {
    await _init();
  }

  Future<void> _init() async {
    await Parse().initialize(
        _applicationId,
        TextConst.defaultURL, //_serverURL,
        debug: true,
        coreStore: await CoreStoreSharedPrefsImp.getInstance(),
    );

    _user = await ParseUser.currentUser();
    _isAnonymous = _prefs.getBool(_keyIsAnonymous)??false;

    if (_isAnonymous) {
      if (_user == null) {
        await _prefs.remove(_keyIsAnonymous);
      } else {
        _user = null;
      }
    }

    if (_user != null) {
      if (! await sessionHealthOk()) {
        _user = null;
      } else {
        _loginId = _user?.username??'';
        onLoggedInChange.send();
      }
    }
  }

  Future<bool> loginAnonymous() async {
    if (_isAnonymous) {
      final ParseUser? user = await ParseUser.currentUser();
      if (user != null) {
        if (await sessionHealthOk()) return true;
      }
      await _prefs.remove(_keyIsAnonymous);
    }

    await logout();

    final parseUser = ParseUser.forQuery();
    final response = await parseUser.loginAnonymous();
    if (!response.success) return false;
    await _prefs.setBool(_keyIsAnonymous, true);
    return true;
  }

  Future<void> logout() async {
    final ParseUser? user = await ParseUser.currentUser();
    if (user == null) {
      if (_user != null) {
        _user = null;
        onLoggedInChange.send();
      }
      return;
    }

    await user.logout();
    if (_user != null) {
      _user = null;
      onLoggedInChange.send();
    }

    if (_isAnonymous) {
      await _prefs.remove(_keyIsAnonymous);
    }
  }

  Future<void> wakeUp() async {
    _serverURL = _prefs.getString(_keyServerURL)??'';
    if (_serverURL.isEmpty) return;

    await _init();
  }

  Future<bool> loginWithPassword(String serverURL, String loginID, String password, bool signUp) async {
    await _setServerURL(serverURL);

    await logout();

    _user = ParseUser(loginID, password, loginID);
    bool result;
    if (signUp) {
      result = (await _user!.signUp()).success;
    } else {
      result = (await _user!.login()).success;
    }

    if (result){
      _loginId = loginID;
      onLoggedInChange.send();
      return true;
    } else {
      _lastError = TextConst.errFailedLogin;
      return false;
    }
  }

  Future<String> loginWith(String provider, Object authData) async {
    await logout();

    final response = await ParseUser.loginWith(provider, authData);

    if (response.success) {
      _user = await ParseUser.currentUser();
      await _user!.fetch();
      _loginId = _user?.username??'';
      onLoggedInChange.send();
      return '';
    } else {
      return TextConst.errFailedLogin;
    }
  }

  Future<bool> loginWithInvite(String serverURL, String inviteKey, LoginMode loginMode, String deviceID) async {
    await _setServerURL(serverURL);

    await logout();

    final sendKeyStr = inviteKey.replaceAll(RegExp('\\D'), '');
    final sendKeyInt = int.tryParse(sendKeyStr);

    const uuid  = Uuid();
    final token = uuid.v4();

    final authData1 = <String, dynamic>{
      'id'        : deviceID,
      'token'     : token,
      'invite_key': sendKeyInt,
      'for'       : loginMode.name,
    };

    // первый запуск на стороне сервера выполняется проверка приглашения
    // и выполняет (linkWith) привязку authData2 id + token к учётной записи пользователя
    var response = await ParseUser.loginWith('decard', authData1);
    if (!response.success) {
      if (response.error!.code    == 101 &&
          response.error!.type    == 'ObjectNotFound' &&
          response.error!.message == 'After linkWith call'
      ){
        // второй запуск должен выполнить вход по уже привязанным данным авторизации
        final authData2 = <String, dynamic>{
          'id'    : deviceID,
          'token' : token,
        };
        response = await ParseUser.loginWith('decard', authData2);
      }
    }

    if (response.success) {
      _user = await ParseUser.currentUser();
      await _user!.fetch();
      _loginId = _user?.username??'';
      onLoggedInChange.send();
      return true;
    } else {
      _lastError = '${TextConst.errFailedLogin}\nhttp code: ${response.error?.code}\n${response.error?.message}';
      return false;
    }
  }

  Future<void> _setServerURL(String serverURL) async {
    _serverURL = serverURL;
    _prefs.setString(_keyServerURL, serverURL);
    await _init();
  }


  Future<bool> sessionHealthOk() async {
    // Parse().healthCheck() - не выдаёт исключение когда сервер доступен но сейсия протухла
    try {
      final query = QueryBuilder<ParseUser>(ParseUser.forQuery());
      query.whereEqualTo('username', user!.username);

      await query.find();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isServerAvailable() async {
    final result = await Parse().healthCheck();
    return result.success;
  }
}