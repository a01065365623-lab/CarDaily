/// 차량 기념일/마일스톤(구매일, 여행, 주행거리 돌파 등).
///
/// [date]는 두 가지 형식을 함께 지원한다:
/// - "MM-DD"(5자): 과거부터 있던 매년 반복 기념일(구매일 등). 연도 없이 저장되어
///   해마다 그 월/일에 자동으로 다시 표시된다.
/// - "yyyy-MM-dd"(10자): 특정 연도에만 표시되는 1회성 기념일(여행 등). 여러 날짜에
///   걸친 일정은 날짜 수만큼 각각 레코드를 만들어 표현한다.
///
/// 두 형식은 문자열 길이로 구분한다(별도 컬럼 없이 기존 데이터와 호환하기 위함).
class Anniversary {
  final int? id;
  final String title;
  final String date; // "MM-DD"(매년 반복) 또는 "yyyy-MM-dd"(1회성)
  final String? memo;
  final String emoji;

  const Anniversary({
    this.id,
    required this.title,
    required this.date,
    this.memo,
    required this.emoji,
  });

  /// "MM-DD" 형식이면 매년 반복되는 기념일이다.
  bool get isRecurring => date.length == 5;

  /// 이 기념일이 실제로 해당하는 구체적인 날짜를 계산한다. D-DAY 배너를 보여줄지
  /// 판단할 때 쓴다. 1회성 기념일([date]가 "yyyy-MM-dd")은 그 날짜 그대로 반환한다.
  /// 매년 반복 기념일([date]가 "MM-DD")은 [today] 기준으로 가장 가까운 발생일을
  /// 계산한다 — 올해 그 월/일이 이미 지났다면 내년 발생일을 반환한다.
  DateTime resolveOccurrenceDate(DateTime today) {
    if (!isRecurring) return DateTime.parse(date);
    final parts = date.split('-');
    final month = int.parse(parts[0]);
    final day = int.parse(parts[1]);
    var occurrence = DateTime(today.year, month, day);
    if (occurrence.isBefore(today)) {
      occurrence = DateTime(today.year + 1, month, day);
    }
    return occurrence;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'memo': memo,
      'emoji': emoji,
    };
  }

  factory Anniversary.fromMap(Map<String, dynamic> map) {
    return Anniversary(
      id: map['id'] as int?,
      title: map['title'] as String,
      date: map['date'] as String,
      memo: map['memo'] as String?,
      emoji: map['emoji'] as String,
    );
  }
}
