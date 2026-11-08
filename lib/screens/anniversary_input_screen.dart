import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../db/database_helper.dart';
import '../models/anniversary.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';

const List<String> _emojiPresets = ['🚗', '🎉', '🏁', '🛣️', '🔧', '✨'];

/// 차량 기념일/마일스톤을 등록하는 화면. 달력에서 하나 이상의 날짜를 선택해
/// (연속 범위 또는 개별 날짜 모두 가능) 저장하면, 선택한 날짜 수만큼 같은
/// 제목/이모지/메모를 공유하는 1회성 기념일 레코드가 각각 만들어진다.
class AnniversaryInputScreen extends StatefulWidget {
  const AnniversaryInputScreen({super.key});

  @override
  State<AnniversaryInputScreen> createState() => _AnniversaryInputScreenState();
}

class _AnniversaryInputScreenState extends State<AnniversaryInputScreen> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  String _emoji = _emojiPresets.first;
  bool _saving = false;

  DateTime _focusedMonth = DateTime.now();
  final Set<DateTime> _selectedDates = {};
  bool _rangeMode = false;
  DateTime? _rangeAnchor;

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _daysBetween(DateTime a, DateTime b) {
    final start = a.isBefore(b) ? a : b;
    final end = a.isBefore(b) ? b : a;
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(_normalize(d));
    }
    return days;
  }

  void _onDaySelected(DateTime day, DateTime focused) {
    final normalized = _normalize(day);
    setState(() {
      _focusedMonth = focused;
      if (_rangeMode) {
        final anchor = _rangeAnchor;
        if (anchor == null) {
          _rangeAnchor = normalized;
          _selectedDates.add(normalized);
        } else {
          _selectedDates.addAll(_daysBetween(anchor, normalized));
          _rangeAnchor = null;
        }
      } else {
        if (_selectedDates.contains(normalized)) {
          _selectedDates.remove(normalized);
        } else {
          _selectedDates.add(normalized);
        }
      }
    });
  }

  void _removeDate(DateTime day) {
    setState(() => _selectedDates.remove(day));
  }

  void _toggleRangeMode(bool value) {
    setState(() {
      _rangeMode = value;
      _rangeAnchor = null;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.anniversaryInputSnackbarNeedTitle)),
      );
      return;
    }
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.anniversaryInputSnackbarNeedDate)),
      );
      return;
    }
    setState(() => _saving = true);
    final memo = _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
    for (final date in _selectedDates) {
      final anniversary = Anniversary(
        title: title,
        date: dateKey(date),
        memo: memo,
        emoji: _emoji,
      );
      await DatabaseHelper.instance.insertAnniversary(anniversary);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat.yMMMd(localeTag);
    final sortedDates = _selectedDates.toList()..sort();
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
          Row(
            children: [
              Expanded(child: _SectionTitle(l10n.anniversaryInputSectionDate)),
              Text(
                _rangeMode ? l10n.anniversaryInputRangeModeLabel : l10n.anniversaryInputSingleModeLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Switch(
                value: _rangeMode,
                onChanged: _toggleRangeMode,
                activeTrackColor: AppColors.amberLight,
                activeColor: AppColors.amber,
              ),
            ],
          ),
          Text(
            _rangeMode ? l10n.anniversaryInputRangeModeHelp : l10n.anniversaryInputSingleModeHelp,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: TableCalendar(
              locale: localeTag,
              firstDay: DateTime(2015, 1, 1),
              lastDay: DateTime(2100, 12, 31),
              focusedDay: _focusedMonth,
              selectedDayPredicate: (day) => _selectedDates.contains(_normalize(day)),
              onDaySelected: _onDaySelected,
              onPageChanged: (focused) => setState(() => _focusedMonth = focused),
              onFormatChanged: (_) {},
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: '월'},
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: AppColors.amberLight,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: AppColors.textPrimary),
                selectedDecoration: BoxDecoration(
                  color: AppColors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          if (sortedDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedDates.map((date) {
                return Chip(
                  label: Text(dateFormat.format(date), style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.amberLight,
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () => _removeDate(date),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
          ],
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
