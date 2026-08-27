import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../db/database_helper.dart';
import '../models/anniversary.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';

const List<String> _emojiPresets = ['🚗', '🎉', '🏁', '🛣️', '🔧', '✨'];

/// 매년 반복되는 차량 기념일/마일스톤을 등록하는 화면. 날짜는 연도 없이 월/일만 선택한다.
class AnniversaryInputScreen extends StatefulWidget {
  const AnniversaryInputScreen({super.key});

  @override
  State<AnniversaryInputScreen> createState() => _AnniversaryInputScreenState();
}

class _AnniversaryInputScreenState extends State<AnniversaryInputScreen> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime _monthDay = DateTime.now();
  String _emoji = _emojiPresets.first;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickMonthDay() async {
    // 연도는 선택에 영향을 주지 않도록 윤년으로 고정해 2/29도 고를 수 있게 한다.
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2024, _monthDay.month, _monthDay.day),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2024, 12, 31),
      helpText: AppLocalizations.of(context)!.anniversaryInputDatePickerHelpText,
    );
    if (picked != null) {
      setState(() => _monthDay = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.anniversaryInputSnackbarNeedTitle)),
      );
      return;
    }
    setState(() => _saving = true);
    final anniversary = Anniversary(
      title: title,
      date: monthDayKey(_monthDay),
      memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
      emoji: _emoji,
    );
    await DatabaseHelper.instance.insertAnniversary(anniversary);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.anniversaryInputAppBarTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionTitle(l10n.anniversaryInputSectionEmoji),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _emojiPresets.map((emoji) {
              final selected = _emoji == emoji;
              return GestureDetector(
                onTap: () => setState(() => _emoji = emoji),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.amberLight : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.amber : AppColors.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.anniversaryInputSectionTitle),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: l10n.anniversaryInputTitleHint,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.anniversaryInputSectionDate),
          InkWell(
            onTap: _pickMonthDay,
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
                  const Icon(Icons.cake_outlined, color: AppColors.amberDark),
                  const SizedBox(width: 10),
                  Text(
                    formatMonthDay(monthDayKey(_monthDay), Localizations.localeOf(context).languageCode),
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
          _SectionTitle(l10n.anniversaryInputSectionMemo),
          TextField(
            controller: _memoController,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.anniversaryInputMemoHint,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(l10n.commonSaveButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
