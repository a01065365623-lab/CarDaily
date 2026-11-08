import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/plan.dart';
import '../theme/app_colors.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 병원 예약까지 며칠 남았는지 세는 D-DAY 카운트다운 + 리마인드/취소 액션.
/// 병원 예약 목록([PlanListScreen])에서 항목을 탭했을 때, 그리고 일자 상세
/// 화면(daily_detail_screen)에서 그 날짜가 오늘/미래이고 아직 지나지 않은
/// 예약일 때 공용으로 쓴다.
class PlanCountdownSection extends StatelessWidget {
  final Plan plan;
  final VoidCallback onRemind;
  final VoidCallback onCancel;

  const PlanCountdownSection({
    super.key,
    required this.plan,
    required this.onRemind,
    required this.onCancel,
  });

  int get _dDay => DateTime.parse(plan.date).difference(_today()).inDays;

  String get _dDayLabel {
    if (_dDay == 0) return 'D-DAY';
    if (_dDay > 0) return 'D-$_dDay';
    return 'D+${-_dDay}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        const Center(child: Text('🏥', style: TextStyle(fontSize: 44))),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _dDayLabel,
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: AppColors.amberDark,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: onRemind,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text(
            l10n.dailyDetailRemindButton,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
          child: Text(
            l10n.dailyDetailCancelPlanButton,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
