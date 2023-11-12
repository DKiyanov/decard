enum LoginMode{
  masterParent,
  slaveParent,
  child
}

class TextConst{
  static String versionDateStr    = '19.09.2023';
  static String version           = 'Версия';
  static String defaultURL        = 'http://192.168.0.202:1337/parse';
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
  static String txtLoading        = 'Загрузка';
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
  static String txtManagement = 'Управление';
  static String txtSelectFile = 'Выбор файлов';
  static String txtAvailableFiles = 'Доступные файлы';
  static String txtFileSources = 'Источники файлов';
  static String txtRefreshFileList = 'Обновить список файлов';
  static String txtUploadFileToChild = 'Загрузить файл детям';
  static String txtWarning = 'Предупреждение';
  static String txtDeleteFile = 'Удалить файл?';
  static String txtPackInfo = 'Общая информация о пакете';
  static String txtCardExcluded = 'Карточка исключена из использования';
  static String txtRegOptions = 'Параметры';
  static String txtRegCardSet = 'Настройка карточек';
  static String txtRegDifficultyLevelsTuning = 'Настройка уровней сложности';
  static String txtRegOptionsTuning = 'Настройка параметров';
  static String txtRegDifficultyTuning = 'Настройка уровнея сложности';
  static String txtCardSetTuning = "Настройка карточек";
  static String txtFile           = "Файл";
  static String txtStatistics = "Статистика";
  static String txtNegativeResultsReport = "Отчёт об ошибках";
  static String txtAllTestResult = "Все результаты тестирования";
  static String txtChartCountCardByStudyGroups = "Кол-во карточек по группам изучености";
  static String txtChartIncomingCardByStudyGroups = "Новые карточки по группам";
  static String txtChartOutgoingCardByStudyGroups = "Покинули группу";
  static String txtRodCardStudyGroupActive = "Активные";
  static String txtRodCardStudyGroupStudied = "Изученные";
  static String txtAutoTest = "Автоматическое тестирование";
  static String txtCardView = "Просмотр карточки";
  static String txtAll = "Всё";
  static String txtQuality = "Качество:";
  static String txtWas = "было";
  static String txtBecame = "стало";
  static String txtStartDate = "Дата начала";
  static String txtTestCount = "Кол-во тестирований";
  static String txtTryCount = "Кол-во попыток";
  static String txtSolveTime = "Длтельность решения";
  static String txtDialogInputText = "Введите текст";
  static String txtHelp = "Помощь";
  static String txtDifficultyColumn1 = "Изменение параметра в процессе изучения";
  static String txtDifficultyColumn2 = "значение\nв начале\nизучения";
  static String txtDifficultyColumn3 = "значение\nв конце\nизучения";
  static String txtDifficultyHelp = '''В процессе усвоения материала значения параметров постепенно изменяются от начального значения к конечному.\n
Во время ответа стоимость будет уменьшаться.\n
Параметр "Длительность" опредяляет время в течении которого будет уменьшаться стоимость.\n
Параметр "Процент снижения стоимости" определяет минимальное значение до которого уменьшится стоимость, за время "Длительность", значение рассчитывается от текущего максимального значения''';


  static String msgChildList1  = 'Ещё нет ни одного ребёнка';
  static String msgChildList2  = 'Выбирите пункт меню "Пригласить ребёнка"';

  static String djfFormatVersion = "Версия формата";
  static String djfTitle         = "Заголовок";
  static String djfGuid          = "Идентификатор";
  static String djfVersion       = "Версия";
  static String djfAuthor        = "Автор";
  static String djfSite          = "Сайт";
  static String djfEmail         = "E-mail";
  static String djfLicense       = "Лицензия";


  static String drfDifficultyLevel    = "Уровень сложности";
  static String drfDifficultyCost     = "Стоимость";
  static String drfDifficultyPenalty  = "Штраф";
  static String drfDifficultyTryCount = "Кол-во попыток";
  static String drfDifficultyDuration = "Длительность";
  static String drfDifficultyDurationLowCostPercent = "Процент снижения стоимости";

  static String drfCardSetCards   = "Идентификаторы карточек";
  static String drfCardSetGroups  = "Группы";
  static String drfCardSetTags    = "Теги";
  static String drfCardSetAndTags = "Теги через И";
  static String drfDifficulties   = "Сложность";

  static String drfExclude        = "Исключить";
  static String drfDifficulty     = "Сложность";

//---------------
  static String drfOptionHotDayCount = 'Количество дней, за которые рассчитывается статистика';

  static String drfOptionHotCardQualityTopLimit = 'Карточки более низкого качества считаются активно изучаемыми';
  static String drfOptionMaxCountHotCard = 'Максимальное количество карточек в активном изучении';

  static String drfOptionHotGroupDetermine = 'Лимиты, определяющие активность группы';
  static String drfOptionHotGroupMinQualityTopLimit = 'Минимальное качество для карточек, входящих в группу';
  static String drfOptionHotGroupAvgQualityTopLimit = 'Среднее качество карточек, входящих в группу';

  static String drfOptionMinCountHotQualityGroup = 'Mинимальное количество активно изучаемых групп карточек';
  static String drfOptionMinCountHotQualityGroupHelp = 'Если количество активно изучаемых групп меньше лимита - система пытается выбрать карту из новой группы';

  static String drfOptionLowGroupAvgQualityTopLimit = 'Верхний предел среднего качества для групп начального уровня качества';

  static String drfOptionMaxCountLowQualityGroup = 'Максимальное количество групп начального уровня качества';
  static String drfOptionMaxCountLowQualityGroupHelp = 'Если количество групп с начальным уровнем качества равно лимиту - система выбирает карточки из уже изучаемых групп';

  static String drfOptionLowHelp = 'Уменьшает качество, при маолом количестве статистики, если новая карта имеет очень хорошие результаты с самого начала,эти параметры не позволят качеству расти слишком быстро';
  static String drfOptionLowTryCount = 'Минимальное количество тестов';
  static String drfOptionLowDayCount = 'Минимальное количество дней';

  static String drfOptionNegativeLastResultMaxQualityLimitHelp = 'Если последний ответ по карточке был не правильный - качество устанавливается в это значение';
  static String drfOptionNegativeLastResultMaxQualityLimit = 'Максимально возможное качество с отрицательным последним результатом';

  static String drfOptionMinEarnTransferMinutes = 'Минимальное количество заработанного времени которое может быть зафиксировано';

  static String errServerUrlEmpty  = 'Не указан адрес сервера';
  static String errServerUnavailable  = 'Сервер недоступен';
  static String errFailedLogin   = 'Не удалось подключиться к серверу';
  static String errFailedSignUp   = 'Не удалось создать учётную запись на сервере';
  static String errInvalidPassword = 'Не правильный пароль';
  static String errInvalidPasswordPinCode = 'Не правильный пароль/пинкод';

  static String txtLoginModeTitle      = 'Выбор режима использования устройства';
  static String txtLoginModeInvitation = 'Выбирите пожалуйста кем будет использоваться это устойство';
  static String txtLoginModeMasterParent = 'Это устройство будет использоваться РОДИТЕЛЕМ\n(организатором группы)';
  static String txtLoginModeSlaveParent = 'Это устройство будет использоваться РОДИТЕЛЕМ\n(участником группы)';
  static String txtLoginModeChild      = 'Это устройство будет использоваться РЕБЁНКОМ';

  static String txtConnecting     = 'Подключение к серверу';
  static String txtCancel            = 'Отменить';
  static String txtEmailAddress   = 'Адрес электронной почты родителя';

  static String txtInvite              = 'Приглашение';
  static String txtInviteExpiration1   = 'Приглашение будет действовать';
  static String txtInviteExpiration2   = 'минут';
  static String txtInviteExpiration3   = 'до';
  static String txtInviteForChildTitle = 'для Ребёнка';
  static String txtInviteChild         = 'Пригласить ребёнка';
  static String txtInviteParent         = 'Пригласить другого родителя';
  static String txtInviteForChildText  = 'введите этот код на устройстве ребёнка при установке приложения или при входе в настройки';
  static String txtInviteForParentTitle = 'для Родителя';
  static String txtInviteForParentText  = 'введите этот код на устройстве другого родителя при установке приложения или при повторном входе';
  static String txtInviteCopied         = 'Код скопирован в буффер обмена';
  static String txtInviteLoginHelp      = 'Получите код приглашения у родителя\nорганизатора группы';
  static String txtInviteKey      = 'Код приглашения';
}

int dateToInt(DateTime date){
  return date.year * 10000 + date.month * 100 + date.day;
}

DateTime intDateToDateTime(int intDate) {
  final year    = intDate     ~/ 10000;
  final rest    = intDate      % 10000;
  final month   = rest        ~/ 100;
  final day     = rest         % 100;

  return DateTime(year, month, day);
}

int dateTimeToInt(DateTime date){
  return date.year * 10000000000 + date.month * 100000000 + date.day * 1000000 + date.hour * 10000 + date.minute * 100 + date.second;
}

DateTime intDateTimeToDateTime(int intDateTime){
  final intDate = intDateTime ~/ 1000000;
  final year    = intDate     ~/ 10000;
  final rest    = intDate      % 10000;
  final month   = rest        ~/ 100;
  final day     = rest         % 100;

  final intTime  = intDateTime % 1000000;
  final hour     = intTime    ~/ 10000;
  final timeRest = intTime     % 10000;
  final minute   = timeRest   ~/ 100;
  final second   = timeRest    % 100;

  return DateTime(year, month, day, hour, minute, second);
}

String dateToStr(DateTime date){
  // конечно нужно использовать intl, но пока так сделаем
  return
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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

double inLimit(double value, {double? low, double? high}) {
  if (low  != null && value < low ) return low;
  if (high != null && value > high) return high;
  return value;
}

double lineValue(double x, double x1, double y1, double x2, double y2) {
  final y = y1 + (x - x1) * (y2 - y1) / (x2 - x1);
  return y;
}

String timeToStr(DateTime time){
  // конечно нужно использовать intl, но пока так сделаем
  return
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}