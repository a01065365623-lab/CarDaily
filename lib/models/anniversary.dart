/// 매년 반복되는 차량 기념일/마일스톤(구매일, 주행거리 돌파 등). [date]는 연도 없이
/// "MM-DD" 형식으로 저장한다.
class Anniversary {
  final int? id;
  final String title;
  final String date; // MM-DD
  final String? memo;
  final String emoji;

  const Anniversary({
    this.id,
    required this.title,
    required this.date,
    this.memo,
    required this.emoji,
  });

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
