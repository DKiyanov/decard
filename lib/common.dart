class TextConst{
  static String defaultURL        = 'http://192.168.0.142:8765';
  static String defaultLogin      = 'decard_stat_writer';
  static String txtServerURL      = 'Адрес сервера';
  static String txtSignUp         = 'Зарегистрироваться';
  static String txtSignIn         = 'Войти';
  static String txtInputAllParams = 'Нужно заполнить все поля';
  static String txtChildName      = 'Имя ребёнка';
  static String txtDeviceName     = 'Имя устройства';
  static String txtInputChildName = 'Введите имя ребёнка';
  static String txtAddNewChild    = 'Добавить нового';
  static String txtAddNewDevice   = 'Добавить новогое';
  static String txtEntryToOptions = 'Вход в настройку';
  static String errServerConnection1 = 'Соединение с сервером не настроено';
  static String txtAppTitle       = 'Карточник';
  static String txtStarting       = 'Запуск';
  static String txtTuningFileSourceList = 'Настройка источников для загрузки карточек';
  static String txtDelete         = 'Удалить';
  static String txtEdit           = 'Редактировать';
  static String txtWrongAnswer  = 'Овет не правильный';
  static String txtRightAnswer    = 'Овет правильный';
  static String txtRightAnswerIs  = 'Правильный ответ:';
  static String txtAnswerIs       = 'Ответ:';
  static String txtSetNextCard    = 'Следующая';
  static String txtInitDirList    = 'Init dir list';
  static String txtScanDirList    = 'Scan dir list';
  static String txtSelectNextCard = 'Select next card';
  static String txtSetTestCard    = 'Set test card';
  static String txtDeleteDB       = 'Delete DB';
  static String txtClearDB        = 'Clear DB';
  static String txtCost           = 'Стоимость:';
  static String txtEarned         = 'Заработано:';
  static String txtPenalty        = 'Штраф:';
  static String txtLocalDir       = 'Локальный каталог';
  static String txtNetworkFileSource  = 'Сетевой ресурс';
  static String txtEditFileSource     = 'Редактирование источника файлов';
  static String txtUrl            = 'Адрес сетевого ресурса';
  static String txtSubPath        = 'Путь внутри сетевого ресурса';
  static String txtLogin          = 'Имя пользователя';
  static String txtPassword       = 'Пароль';
  static String txtInvalidUrl     = 'Не корректный адрес источника';
  static String txtUsingModeTitle = 'Выбор режима использования приложения';
  static String txtUsingModeInvitation = 'Выбирите пожалуйста как будет использоваться это устойство';
  static String txtUsingModeTesting = 'Тестирование';
  static String txtUsingModeCardEdit = 'Создание и редактирование карточек для тестирования';
  static String txtProceed        = 'Продолжить';
  static String txtPasswordEntry  = 'Ввод пароля';
  static String txtInputPassword  = 'Ведите пароль';
  static String txtChangingPassword  = 'Изменение пароля';
  static String txtPickPassword   = 'Придумайте пароль';
  static String txtPasswordJustification = 'Пароль хранится локально и используется только для обеспечения контроля доступа к настройкам программы';
  static String txtOptions = 'Настройки';
  static String txtDemo = 'Просмотр карточек';
  static String txtTesting = 'Тестирование';
  static String txtStartTest = 'Запустить тест';
  static String txtMinEarnInput = 'Виличина минимального зароботка';
  static String txtMinEarnHelp = 'Минимальная величина зароботка которая может быть зачтена';
  static String errSetMinEarn = 'Укажите величину минимального зароботка';
  static String txtUploadStatUrl = 'Адрес для выгрузки статистики';
  static String txtIncorrectPassword = 'Введён не корректный пароль';
  static String errPasswordIsEmpty = 'Пароль не должен быть пустым';
  static String errInvalidValue = 'Не корректное значение';
  static String txtStartTesting = 'Начать тестирование';
  static String txtUploadErrorInfo = 'При загрузке файлов возникли ошибки';
  static String txtDbFileListTitle = 'Загруженные файлы';
  static String txtDownloadingInProgress = 'Загрузка выполняется';
  static String txtDownloadNewFiles = 'Загрузить новые файлы';
  static String txtNoCards = 'Нет карточек для показа';
  static String txtLastDownloadError = 'Ошибки последней завершонной загрузки';
}

int dateToInt(DateTime date){
  return date.year * 10000 + date.month * 100 + date.day;
}

enum UrlType {
  httpUrl,
  localPath
}

UrlType getUrlType(String url) {
  final prefix = url.split('://').first.toLowerCase();
  if (["http", "https"].contains(prefix)) return UrlType.httpUrl;
  return UrlType.localPath;
}

String getEarnedText(double earnedSeconds){
  final minutes = (earnedSeconds / 60).truncate();
  final seconds = (earnedSeconds - minutes * 60).truncate();
  return '$minutes:$seconds';
}
