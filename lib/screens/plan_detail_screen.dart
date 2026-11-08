import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../db/database_helper.dart';
import '../models/plan.dart';
import '../theme/app_colors.dart';
import '../widgets/plan_countdown_section.dart';
import 'plan_input_screen.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 저장된 병원 예약 하나의 상세 화면. 정보 카드와 "수정" 버튼은 항상 보여주고,
/// 그 예약 날짜가 오늘보다 이후(미래)일 때만 D-DAY 카운트다운과 리마인드/취소
/// 액션([PlanCountdownSection])을 추가로 보여준다. 예약 당일이 되거나 이미
/// 지난 날짜는 D-DAY 없이 정보 카드만 보여준다.
class PlanDetailScreen extends StatefulWidget {
  final Plan plan;

  const PlanDetailScreen({super.key, required this.plan});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  late Plan _plan = widget.plan;
  bool _changed = false;

  bool get _isFuture => DateTime.parse(_plan.date).isAfter(_today());

  void _remind() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.dailyDetailSnackbarPlanReminder,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.dailyDetailCancelPlanDialogTitle),
            content: Text(l10n.dailyDetailCancelPlanDialogContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.dailyDetailDialogNo),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.dailyDetailDialogConfirmCancel),
              ),
            ],
          ),
    );
    if (confirmed != true || _plan.id == null) return;
    await DatabaseHelper.instance.deletePlan(_plan.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => PlanInputScreen(
              initialDate: DateTime.parse(_plan.date),
              existingPlan: _plan,
            ),
      ),
    );
    if (saved != true || _plan.id == null) return;
    final updated = await DatabaseHelper.instance.getPlanById(_plan.id!);
    if (!mounted || updated == null) return;
    setState(() {
      _plan = updated;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_plan.date),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            TextButton(onPressed: _edit, child: Text(l10n.commonEditButton)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _PlanInfoCard(plan: _plan),
            if (_isFuture)
              PlanCountdownSection(
                plan: _plan,
                onRemind: _remind,
                onCancel: _cancel,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanInfoCard extends StatelessWidget {
  final Plan plan;

  const _PlanInfoCard({required this.plan});

  bool get _isFuture => DateTime.parse(plan.date).isAfter(_today());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sageBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                color: AppColors.sage,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isFuture
                      ? l10n.dailyDetailPlannedSectionTitle
                      : l10n.dailyDetailVisitedSectionTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sage,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  plan.type.localizedLabel(context),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (plan.companionTag != null && plan.companionTag!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plan.companionTag!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (plan.memo != null && plan.memo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.memo!,
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
