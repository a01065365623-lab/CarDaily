import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../db/database_helper.dart';
import '../models/anniversary.dart';
import '../models/companion_tag.dart';
import '../models/drive.dart';
import '../models/plan.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import '../utils/photo_storage.dart';
import '../widgets/shop_link_sheet.dart';
import 'photo_gallery_screen.dart';
import 'plan_input_screen.dart';
import 'record_input_screen.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class DailyDetailScreen extends StatefulWidget {
  final DateTime date;

  const DailyDetailScreen({super.key, required this.date});

  @override
  State<DailyDetailScreen> createState() => _DailyDetailScreenState();
}

class _DailyDetailScreenState extends State<DailyDetailScreen> {
  List<Drive> _drives = [];
  Plan? _plan;
  Drive? _lastYearEntry;
  Anniversary? _anniversary;
  bool _loading = true;

  bool get _isTodayOrFuture => !widget.date.isBefore(_today());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final key = dateKey(widget.date);
    final drives = await DatabaseHelper.instance.getDrivesForDate(key);
    Plan? plan;
    if (_isTodayOrFuture) {
      plan = await DatabaseHelper.instance.getPlanForDate(key);
    }
    final lastYearEntry = await _loadLastYearEntry();
    final anniversary = await DatabaseHelper.instance.getAnniversaryForMonthDay(monthDayKey(widget.date));
    if (!mounted) return;
    setState(() {
      _drives = drives;
      _plan = plan;
      _lastYearEntry = lastYearEntry;
      _anniversary = anniversary;
      _loading = false;
    });
  }

  Future<Drive?> _loadLastYearEntry() async {
    final d = widget.date;
    final lastYearDate = DateTime(d.year - 1, d.month, d.day);
    final drives = await DatabaseHelper.instance.getDrivesForDate(dateKey(lastYearDate));
    return drives.isEmpty ? null : drives.first;
  }

  double get _totalDistanceKm => _drives.fold(0, (sum, d) => sum + (d.distanceKm ?? 0));

  Future<void> _addRecord() async {
    final result = await Navigator.of(context).push<RecordSaveResult>(
      MaterialPageRoute(builder: (_) => RecordInputScreen(date: widget.date)),
    );
    _load();
    if (!mounted || result == null) return;
    _showShopSnackbar(result.shopQuery);
  }

  /// 방금 저장한 운행 기록의 목적에 맞는 쇼핑 검색을 바로 열어볼 수 있는
  /// 액션 버튼이 달린 스낵바를 띄운다.
  void _showShopSnackbar(String shopQuery) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.recordInputSavedSnackbarMessage,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // 기본 4초는 "관련 상품 보기"를 누르기엔 너무 빨리 사라져서, 사용자가
        // 직접 닫거나(스와이프) 다른 화면으로 넘어가기 전까지는 계속 남아있게 한다.
        duration: const Duration(minutes: 10),
        action: SnackBarAction(
          label: l10n.shopSideDishAction,
          onPressed: () => openShoppingSearch(context, shopQuery),
        ),
      ),
    );
  }

  Future<void> _addPlan() async {
    final l10n = AppLocalizations.of(context)!;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PlanInputScreen(initialDate: widget.date)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dailyDetailSnackbarPlanSaved)),
      );
    }
    _load();
  }

  void _remindPlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.dailyDetailSnackbarPlanReminder)),
    );
  }

  Future<void> _cancelPlan() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dailyDetailCancelPlanDialogTitle),
        content: Text(l10n.dailyDetailCancelPlanDialogContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.dailyDetailDialogNo)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.dailyDetailDialogConfirmCancel)),
        ],
      ),
    );
    if (confirmed != true || _plan?.id == null) return;
    await DatabaseHelper.instance.deletePlan(_plan!.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _deleteAnniversary() async {
    final anniversary = _anniversary;
    if (anniversary?.id == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.anniversaryListDeleteDialogTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancelButton)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: Text(l10n.dailyDetailDialogDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteAnniversary(anniversary!.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.anniversaryListSnackbarDeleted(anniversary.title))),
    );
    _load();
  }

  Future<void> _deleteDrive(Drive drive) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dailyDetailDeleteLogDialogTitle),
        content: Text(l10n.dailyDetailDeleteLogDialogContent(drive.routeSummary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancelButton)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.dailyDetailDialogDelete)),
        ],
      ),
    );
    if (confirmed != true || drive.id == null) return;
    await DatabaseHelper.instance.deleteDrive(drive.id!);
    for (final path in drive.photoPaths) {
      await deleteImageFile(path);
    }
    _load();
  }

  /// 이 날짜의 모든 운행 기록(사진 포함)을 한 번에 삭제한다.
  Future<void> _resetDay() async {
    final l10n = AppLocalizations.of(context)!;
    final allPhotos = _drives.expand((d) => d.photoPaths).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dailyDetailResetDayDialogTitle),
        content: Text(l10n.dailyDetailResetDayDialogContent(_drives.length, allPhotos.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancelButton)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: Text(l10n.dailyDetailDialogDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteDrivesForDate(dateKey(widget.date));
    for (final photo in allPhotos) {
      await deleteImageFile(photo);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.dailyDetailResetDaySnackbarMessage)),
    );
    _load();
  }

  void _openGallery(Drive drive, {int initialIndex = 0}) {
    if (drive.photoPaths.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoGalleryScreen(photoPaths: drive.photoPaths, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _drives.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(dateKey(widget.date)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (showFab)
            IconButton(
              tooltip: AppLocalizations.of(context)!.dailyDetailResetDayTooltip,
              onPressed: _resetDay,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_plan != null)
                  _PlanSection(
                    plan: _plan!,
                    date: widget.date,
                    onRemind: _remindPlan,
                    onCancel: _cancelPlan,
                  ),
                if (_plan == null && _isTodayOrFuture) _AddPlanCta(onAdd: _addPlan),
                if (_plan != null || (_plan == null && _isTodayOrFuture)) const SizedBox(height: 16),
                if (_drives.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.amberLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.dailyDetailDistanceTotalLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${_totalDistanceKm.toStringAsFixed(1)}km',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amberDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final drive in _drives) ...[
                    _DriveTile(
                      drive: drive,
                      onDelete: () => _deleteDrive(drive),
                      onTapPhoto: () => _openGallery(drive),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                if (_anniversary != null) ...[
                  const SizedBox(height: 16),
                  _AnniversaryDayCard(anniversary: _anniversary!, onDelete: _deleteAnniversary),
                ] else if (_lastYearEntry != null) ...[
                  const SizedBox(height: 16),
                  _LastYearCard(drive: _lastYearEntry!),
                ],
              ],
            ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () => _addRecord(),
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

class _PlanSection extends StatelessWidget {
  final Plan plan;
  final DateTime date;
  final VoidCallback onRemind;
  final VoidCallback onCancel;

  const _PlanSection({
    required this.plan,
    required this.date,
    required this.onRemind,
    required this.onCancel,
  });

  int get _dDay => date.difference(_today()).inDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanInfoCard(plan: plan),
        const SizedBox(height: 28),
        const Center(
          child: Text('🔧', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _dDay == 0 ? 'D-DAY' : 'D-$_dDay',
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text(l10n.dailyDetailRemindButton, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
          child: Text(l10n.dailyDetailCancelPlanButton, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _PlanInfoCard extends StatelessWidget {
  final Plan plan;

  const _PlanInfoCard({required this.plan});

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.build_circle_outlined, color: AppColors.sage, size: 18),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.dailyDetailPlannedSectionTitle,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sage),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          if (plan.companionTag != null && plan.companionTag!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plan.companionTag!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          if (plan.memo != null && plan.memo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.memo!,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddPlanCta extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddPlanCta({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: AppColors.sage),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.dailyDetailAddPlanCta,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveTile extends StatelessWidget {
  final Drive drive;
  final VoidCallback onDelete;
  final VoidCallback onTapPhoto;

  const _DriveTile({
    required this.drive,
    required this.onDelete,
    required this.onTapPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final thumbnailPath = drive.photoPaths.isEmpty ? null : drive.photoPaths.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: thumbnailPath == null ? null : onTapPhoto,
            child: thumbnailPath == null
                ? const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.amberLight,
                    child: Text('🚗', style: TextStyle(fontSize: 20)),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(thumbnailPath),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => openShoppingSearch(context, drive.purposeTag.shopQuery(context)),
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    drive.routeSummary,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.amberDark,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ),
                if (drive.startTime != null || drive.endTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${drive.startTime ?? '--:--'} → ${drive.endTime ?? '--:--'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniTag(
                      text: CompanionTag.displayList(context, drive.companionTags),
                      color: AppColors.sage,
                      bg: AppColors.sageBg,
                    ),
                    _MiniTag(
                      text: drive.purposeTag.localizedLabel(context),
                      color: AppColors.route,
                      bg: AppColors.routeBg,
                    ),
                    _MiniTag(
                      text: '${drive.moodTag.emoji} ${drive.moodTag.localizedLabel(context)}'
                          '${drive.moodDetail != null ? ' · ${drive.moodDetail}' : ''}',
                      color: AppColors.terracotta,
                      bg: AppColors.terracottaBg,
                    ),
                    if (drive.distanceKm != null)
                      _MiniTag(
                        text: l10n.dailyDetailDistanceTagLabel(drive.distanceKm!.toStringAsFixed(1)),
                        color: AppColors.amberDark,
                        bg: AppColors.amberLight,
                      ),
                  ],
                ),
                if (drive.memo != null && drive.memo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    drive.memo!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _MiniTag({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _LastYearCard extends StatelessWidget {
  final Drive drive;

  const _LastYearCard({required this.drive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.woodBrownLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.dailyDetailLastYearTitle,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.woodBrown),
          ),
          const SizedBox(height: 8),
          Text(
            '${drive.routeSummary} · ${CompanionTag.displayList(context, drive.companionTags)} · '
            '${drive.moodTag.emoji} ${drive.moodTag.localizedLabel(context)}',
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AnniversaryDayCard extends StatelessWidget {
  final Anniversary anniversary;
  final VoidCallback onDelete;

  const _AnniversaryDayCard({required this.anniversary, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.terracottaBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.dailyDetailAnniversaryTitle(anniversary.emoji, anniversary.title),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(l10n.dailyDetailDialogDelete),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (anniversary.memo != null && anniversary.memo!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              anniversary.memo!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
