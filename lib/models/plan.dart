/// 아직 일어나지 않은 정비 예약. [date]는 오늘 또는 미래 날짜만 허용한다.
class Plan {
  final int? id;
  final String date; // yyyy-MM-dd
  final String title;
  /// 정비소/담당자 이름(자유 텍스트, 선택 입력).
  final String? companionTag;
  final String? memo;
  final DateTime createdAt;

  Plan({
    this.id,
    required this.date,
    required this.title,
    this.companionTag,
    this.memo,
    required this.createdAt,
  });

  factory Plan.create({
    required String date,
    required String title,
    String? companionTag,
    String? memo,
  }) {
    return Plan(
      date: date,
      title: title,
      companionTag: companionTag,
      memo: memo,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'title': title,
      'companionTag': companionTag,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'] as int?,
      date: map['date'] as String,
      title: map['title'] as String,
      companionTag: map['companionTag'] as String?,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
