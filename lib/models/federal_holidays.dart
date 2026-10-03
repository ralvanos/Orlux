class FederalHolidays {
  FederalHolidays._();

  static bool isHoliday(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    for (final holiday in datesForYear(date.year)) {
      if (holiday.year == date.year &&
          holiday.month == date.month &&
          holiday.day == date.day) {
        return true;
      }
    }
    return false;
  }

  static DateTime nextBusinessDayAt(DateTime at) {
    var next = DateTime(at.year, at.month, at.day).add(const Duration(days: 1));
    while (_isWeekend(next) || isHoliday(next)) {
      next = next.add(const Duration(days: 1));
    }
    return DateTime(next.year, next.month, next.day, at.hour, at.minute);
  }

  static bool _isWeekend(DateTime day) =>
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  static DateTime _observed(int year, int month, int day) {
    final date = DateTime(year, month, day);
    if (date.weekday == DateTime.saturday) {
      return date.subtract(const Duration(days: 1));
    }
    if (date.weekday == DateTime.sunday) {
      return date.add(const Duration(days: 1));
    }
    return date;
  }

  static DateTime _nthWeekday(int year, int month, int weekday, int n) {
    var date = DateTime(year, month, 1);
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return date.add(Duration(days: 7 * (n - 1)));
  }

  static DateTime _lastWeekday(int year, int month, int weekday) {
    var date = DateTime(year, month + 1, 0);
    while (date.weekday != weekday) {
      date = date.subtract(const Duration(days: 1));
    }
    return date;
  }

  /// U.S. federal holidays, observed (weekend shifts to Friday/Monday).
  static List<DateTime> datesForYear(int year) {
    return [
      _observed(year, 1, 1),
      _nthWeekday(year, 1, DateTime.monday, 3),
      _nthWeekday(year, 2, DateTime.monday, 3),
      _lastWeekday(year, 5, DateTime.monday),
      _observed(year, 6, 19),
      _observed(year, 7, 4),
      _nthWeekday(year, 9, DateTime.monday, 1),
      _nthWeekday(year, 10, DateTime.monday, 2),
      _observed(year, 11, 11),
      _nthWeekday(year, 11, DateTime.thursday, 4),
      _observed(year, 12, 25),
    ];
  }
}
