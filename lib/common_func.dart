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