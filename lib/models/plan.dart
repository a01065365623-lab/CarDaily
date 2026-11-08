import 'plan_type.dart';

/// 병원 예약(또는 다녀온 기록). [date]는 과거/오늘/미래 어느 날짜든 허용한다.
class Plan {
  final int? id;
  final String date; // yyyy-MM-dd
  final String title;

  /// 병원(정비소)/담당자 이름(자유 텍스트, 선택 입력).
  final String? companionTag;
  final String? memo;
  final DateTime createdAt;
  final PlanType type;

  Plan({
    this.id,
    required this.date,
    required this.title,
    this.companionTag,
    this.memo,
    required this.createdAt,
    required this.type,
  });

  factory Plan.create({
    required String date,
    required String title,
    String? companionTag,
    String? memo,
    required PlanType type,
  }) {
    return Plan(
      date: date,
      title: title,
      companionTag: companionTag,
      memo: memo,
      createdAt: DateTime.now(),
      type: type,
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
      'type': type.dbValue,
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
      type: PlanType.fromDbValue(map['type'] as String),
    );
  }
}
