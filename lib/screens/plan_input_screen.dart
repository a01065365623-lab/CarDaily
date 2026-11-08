import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../db/database_helper.dart';
import '../models/plan.dart';
import '../models/plan_type.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';

/// 병원 예약을 등록하거나([existingPlan]이 null) 수정하는([existingPlan]이 있음)
/// 화면. 과거/오늘/미래 날짜 모두 선택하고 저장할 수 있다 — 이미 다녀온 병원
/// 기록을 나중에 입력하는 경우도 지원해야 하기 때문이다.
class PlanInputScreen extends StatefulWidget {
  final DateTime initialDate;
  final Plan? existingPlan;

  const PlanInputScreen({
    super.key,
    required this.initialDate,
    this.existingPlan,
  });

  @override
  State<PlanInputScreen> createState() => _PlanInputScreenState();
}

class _PlanInputScreenState extends State<PlanInputScreen> {
  late DateTime _date =
      widget.existingPlan != null
          ? DateTime.parse(widget.existingPlan!.date)
          : DateTime(
            widget.initialDate.year,
            widget.initialDate.month,
            widget.initialDate.day,
          );
  late PlanType _type = widget.existingPlan?.type ?? PlanType.maintenance;
  late final _titleController = TextEditingController(
    text: widget.existingPlan?.title ?? '',
  );
  late final _garageController = TextEditingController(
    text: widget.existingPlan?.companionTag ?? '',
  );
  late final _memoController = TextEditingController(
    text: widget.existingPlan?.memo ?? '',
  );
  bool _saving = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _garageController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.planInputSnackbarNeedTitle)));
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.existingPlan;
      if (existing != null) {
        final updated = Plan(
          id: existing.id,
          date: dateKey(_date),
          title: title,
          companionTag:
              _garageController.text.trim().isEmpty
                  ? null
                  : _garageController.text.trim(),
          memo:
              _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
          createdAt: existing.createdAt,
          type: _type,
        );
        await DatabaseHelper.instance.updatePlan(updated);
      } else {
        final plan = Plan.create(
          date: dateKey(_date),
          title: title,
          companionTag:
              _garageController.text.trim().isEmpty
                  ? null
                  : _garageController.text.trim(),
          memo:
              _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
          type: _type,
        );
        await DatabaseHelper.instance.insertPlan(plan);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.planInputSnackbarSaveFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.planInputAppBarTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionTitle(l10n.planInputSectionDate),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, color: AppColors.amberDark),
                  const SizedBox(width: 10),
                  Text(
                    dateKey(_date),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.planInputSectionType),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                PlanType.values.map((type) {
                  final selected = _type == type;
                  return ChoiceChip(
                    label: Text(type.localizedLabel(context)),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = type),
                    selectedColor: AppColors.terracotta,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.terracottaBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.planInputSectionTitle),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: l10n.planInputTitleHint,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.planInputSectionCompanion),
          TextField(
            controller: _garageController,
            decoration: InputDecoration(
              hintText: l10n.planInputCompanionHint,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.planInputSectionMemo),
          TextField(
            controller: _memoController,
            maxLength: 500,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.planInputMemoHint,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.amber.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child:
                  _saving
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                      : Text(
                        l10n.planInputSaveButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
