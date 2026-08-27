import 'package:intl/intl.dart';

/// DB에 저장하는 날짜 키(yyyy-MM-dd) 포맷.
final DateFormat dbDateFormat = DateFormat('yyyy-MM-dd');

String dateKey(DateTime date) => dbDateFormat.format(date);

/// 기념일 저장용 "MM-DD" 키(연도 없이 매년 반복).
String monthDayKey(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// "MM-DD" 문자열을 현재 언어에 맞는 월/일 형태(예: "8월 27일", "August 27")로 보여준다.
/// [localeTag]는 [Localizations.localeOf]로 얻은 현재 앱 언어 코드.
String formatMonthDay(String monthDay, String localeTag) {
  final parts = monthDay.split('-');
  final month = int.parse(parts[0]);
  final day = int.parse(parts[1]);
  // 연도는 표시에 쓰이지 않으므로 윤년으로 고정해 2/29도 안전하게 포맷한다.
  final date = DateTime(2024, month, day);
  return DateFormat.MMMd(localeTag).format(date);
}
