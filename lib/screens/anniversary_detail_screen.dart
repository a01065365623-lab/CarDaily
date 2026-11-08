import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../models/anniversary.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import '../widgets/anniversary_countdown_section.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 저장된 기념일/마일스톤 하나의 상세 화면. [occurrenceDate]는 이 기념일이
/// 실제로 해당하는 구체적인 날짜다 — 매년 반복 기념일은 "MM-DD"만 저장하므로,
/// 호출하는 쪽에서 연도를 채운 구체적인 날짜를 함께 넘겨줘야 한다
/// ([Anniversary.resolveOccurrenceDate] 참고). occurrenceDate가 오늘보다
/// 이후일 때만 D-DAY 배너를 보여주고, 오늘이거나 지난 날짜는 정보 카드만
/// 보여준다.
class AnniversaryDetailScreen extends StatelessWidget {
  final Anniversary anniversary;
  final DateTime occurrenceDate;

  const AnniversaryDetailScreen({
    super.key,
    required this.anniversary,
    required this.occurrenceDate,
  });

  bool get _isFuture => occurrenceDate.isAfter(_today());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(dateKey(occurrenceDate)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _AnniversaryInfoCard(
            anniversary: anniversary,
            occurrenceDate: occurrenceDate,
          ),
          if (_isFuture)
            AnniversaryCountdownSection(
              emoji: anniversary.emoji,
              occurrenceDate: occurrenceDate,
            ),
        ],
      ),
    );
  }
}

class _AnniversaryInfoCard extends StatelessWidget {
  final Anniversary anniversary;
  final DateTime occurrenceDate;

  const _AnniversaryInfoCard({
    required this.anniversary,
    required this.occurrenceDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).languageCode;
    final dateLabel =
        anniversary.isRecurring
            ? l10n.anniversaryListRepeatsYearlyPrefix(
              formatMonthDay(anniversary.date, localeTag),
            )
            : DateFormat.yMMMd(localeTag).format(occurrenceDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.terracottaBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(anniversary.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  anniversary.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (anniversary.memo != null && anniversary.memo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              anniversary.memo!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
