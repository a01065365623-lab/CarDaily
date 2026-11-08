import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 기념일까지 며칠 남았는지 보여주는 D-DAY 배너. 병원 예약의
/// [PlanCountdownSection]과 같은 시각 스타일을 쓰되, 기념일은 리마인드/취소
/// 개념이 없으므로 배너만 보여준다. 호출하는 쪽에서 날짜가 오늘보다 이후일 때만
/// (occurrenceDate.isAfter(today)) 이 위젯을 노출해야 한다.
class AnniversaryCountdownSection extends StatelessWidget {
  final String emoji;
  final DateTime occurrenceDate;

  const AnniversaryCountdownSection({
    super.key,
    required this.emoji,
    required this.occurrenceDate,
  });

  int get _dDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return occurrenceDate.difference(today).inDays;
  }

  String get _dDayLabel => _dDay == 0 ? 'D-DAY' : 'D-$_dDay';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Center(child: Text(emoji, style: const TextStyle(fontSize: 44))),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _dDayLabel,
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: AppColors.terracotta,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
