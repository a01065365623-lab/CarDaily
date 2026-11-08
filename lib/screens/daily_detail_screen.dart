import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/anniversary.dart';
import '../models/companion_tag.dart';
import '../models/drive.dart';
import '../models/fuel_log.dart';
import '../models/plan.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import '../utils/photo_storage.dart';
import '../utils/shop_query.dart';
import '../widgets/shop_link_sheet.dart';
import 'anniversary_detail_screen.dart';
import 'drive_detail_screen.dart';
import 'fuel_log_detail_screen.dart';
import 'photo_gallery_screen.dart';
import 'plan_detail_screen.dart';
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
  FuelLog? _fuelLog;
  Drive? _lastYearEntry;
  Anniversary? _anniversary;
  bool _loading = true;

  /// 카드를 빠르게 여러 번 탭했을 때 Navigator.push가 겹쳐 들어가는 것을 막는다.
  bool _isNavigating = false;

  /// 이 날짜 전체 캡처(공유용 이미지 생성) 진행 중 여부. 중복 탭을 막고 공유
  /// 버튼에 로딩 표시를 하는 데 쓴다.
  bool _sharing = false;

  /// 상세 공유 캡처가 진행 중인 drives.id 집합. 중복 탭을 막는 데 쓴다.
  final Set<int> _sharingDriveIds = {};

  bool get _isTodayOrFuture => !widget.date.isBefore(_today());
  bool get _isFuture => widget.date.isAfter(_today());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final key = dateKey(widget.date);
    final drives = await DatabaseHelper.instance.getDrivesForDate(key);
    // 날짜(과거/오늘/미래)에 상관없이 그 날 예약이 있으면 보여준다. 미래 예약이면
    // 아직 남은 일정, 과거/오늘이면 다녀온 기록으로 자연스럽게 읽힌다.
    final plan = await DatabaseHelper.instance.getPlanForDate(key);
    final fuelLog = await DatabaseHelper.instance.getFuelLogForDate(key);
    final lastYearEntry = await _loadLastYearEntry();
    // 특정 연도의 1회성 기념일을 먼저 찾고, 없으면 매년 반복되는 기념일을 찾는다.
    final anniversary =
        await DatabaseHelper.instance.getAnniversaryForDate(key) ??
        await DatabaseHelper.instance.getAnniversaryForMonthDay(
          monthDayKey(widget.date),
        );
    if (!mounted) return;
    setState(() {
      _drives = drives;
      _plan = plan;
      _fuelLog = fuelLog;
      _lastYearEntry = lastYearEntry;
      _anniversary = anniversary;
      _loading = false;
    });
  }

  Future<Drive?> _loadLastYearEntry() async {
    final d = widget.date;
    final lastYearDate = DateTime(d.year - 1, d.month, d.day);
    final drives = await DatabaseHelper.instance.getDrivesForDate(
      dateKey(lastYearDate),
    );
    return drives.isEmpty ? null : drives.first;
  }

  double get _totalDistanceKm =>
      _drives.fold(0, (sum, d) => sum + (d.distanceKm ?? 0));

  Future<void> _addRecord() async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => RecordInputScreen(date: widget.date)),
      );
      if (!mounted) return;
      _load();
      if (result != true) return;
      showRecordSavedSnackbar(context);
    } finally {
      _isNavigating = false;
    }
  }

  /// 좌측 하단 쇼핑 FAB의 동작. resolveShopQueryForDate로 이 날짜에 맞는 검색어를
  /// 골라 쇼핑 링크를 연다.
  Future<void> _openShopFromDay() async {
    final query = await resolveShopQueryForDate(context, widget.date);
    if (!mounted) return;
    await openShoppingSearch(context, query);
  }

  Future<void> _addPlan() async {
    final l10n = AppLocalizations.of(context)!;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanInputScreen(initialDate: widget.date),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dailyDetailSnackbarPlanSaved)),
      );
    }
    _load();
  }

  Future<void> _openPlanDetail() async {
    if (_isNavigating) return;
    final plan = _plan;
    if (plan == null) return;
    _isNavigating = true;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlanDetailScreen(plan: plan)));
      if (!mounted) return;
      _load();
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _openDriveDetail(Drive drive) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DriveDetailScreen(drive: drive)),
      );
      if (!mounted) return;
      _load();
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _openFuelLogDetail() async {
    if (_isNavigating) return;
    final fuelLog = _fuelLog;
    if (fuelLog == null) return;
    _isNavigating = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FuelLogDetailScreen(fuelLog: fuelLog),
        ),
      );
      if (!mounted) return;
      _load();
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _openAnniversaryDetail() async {
    if (_isNavigating) return;
    final anniversary = _anniversary;
    if (anniversary == null) return;
    _isNavigating = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => AnniversaryDetailScreen(
                anniversary: anniversary,
                occurrenceDate: widget.date,
              ),
        ),
      );
      if (!mounted) return;
      _load();
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _deleteAnniversary() async {
    final anniversary = _anniversary;
    if (anniversary?.id == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.anniversaryListDeleteDialogTitle),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
                child: Text(l10n.dailyDetailDialogDelete),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteAnniversary(anniversary!.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.anniversaryListSnackbarDeleted(anniversary.title)),
      ),
    );
    _load();
  }

  Future<void> _deleteDrive(Drive drive) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.dailyDetailDeleteLogDialogTitle),
            content: Text(
              l10n.dailyDetailDeleteLogDialogContent(drive.routeSummary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.dailyDetailDialogDelete),
              ),
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
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.dailyDetailResetDayDialogTitle),
            content: Text(
              l10n.dailyDetailResetDayDialogContent(
                _drives.length,
                allPhotos.length,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
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

  Future<void> _openGallery(Drive drive, {int initialIndex = 0}) async {
    if (_isNavigating || drive.photoPaths.isEmpty) return;
    _isNavigating = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => PhotoGalleryScreen(
                photoPaths: drive.photoPaths,
                initialIndex: initialIndex,
              ),
        ),
      );
    } finally {
      _isNavigating = false;
    }
  }

  /// 화면에 보이는 스크롤 리스트와, 공유 이미지 캡처용 오프스크린 렌더링이
  /// 이 목록을 그대로 함께 쓴다.
  List<Widget> _buildBodyChildren() {
    return [
      if (_plan != null) _PlanRecordCard(plan: _plan!, onTap: _openPlanDetail),
      if (_plan == null && _isTodayOrFuture)
        _AddPlanCta(onAdd: _addPlan, isFuture: _isFuture),
      if (_plan != null || (_plan == null && _isTodayOrFuture))
        const SizedBox(height: 16),
      if (_drives.isNotEmpty) ...[
        InkWell(
          onTap: _fuelLog == null ? null : _openFuelLogDetail,
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
        ),
        const SizedBox(height: 12),
        for (final drive in _drives) ...[
          _DriveTile(
            drive: drive,
            onDelete: () => _deleteDrive(drive),
            onShare: () => _shareDriveDetail(drive),
            onTapPhoto: () => _openGallery(drive),
            onTap: () => _openDriveDetail(drive),
          ),
          const SizedBox(height: 10),
        ],
      ],
      if (_anniversary != null) ...[
        const SizedBox(height: 16),
        _AnniversaryDayCard(
          anniversary: _anniversary!,
          onDelete: _deleteAnniversary,
          onTap: _openAnniversaryDetail,
        ),
      ] else if (_lastYearEntry != null) ...[
        const SizedBox(height: 16),
        _LastYearCard(drive: _lastYearEntry!),
      ],
    ];
  }

  Widget _buildShareHeader() {
    return Text(
      dateKey(widget.date),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// 이 날짜의 기록 카드 리스트 전체(스크롤 영역 전체 높이)를 이미지로 캡처해서
  /// 공유 시트로 내보낸다. 실제로 보이는 뷰포트만이 아니라 전체 리스트가 들어가도록,
  /// 같은 내용을 [ListView] 대신 자연 높이의 [Column]으로 화면 밖(오프스크린)에
  /// 렌더링한 뒤 그 [RepaintBoundary]를 캡처한다.
  Future<void> _shareDayAsImage() async {
    if (_sharing) return;
    if (_drives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.dailyDetailShareEmptyMessage,
          ),
        ),
      );
      return;
    }

    setState(() => _sharing = true);
    final captureKey = GlobalKey();
    final overlay = Overlay.of(context);
    final width = MediaQuery.of(context).size.width;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (ctx) => Positioned(
            left: 0,
            top: -20000,
            width: width,
            child: RepaintBoundary(
              key: captureKey,
              child: Material(
                color: AppColors.background,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildShareHeader(),
                      const SizedBox(height: 16),
                      ..._buildBodyChildren(),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    try {
      overlay.insert(entry);
      // 오프스크린 위젯의 레이아웃/페인트(사진 썸네일 디코딩 포함)가 끝날 때까지
      // 프레임을 몇 차례 흘려보낸다.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = captureKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('capture boundary not found');
      }
      final image = await renderObject.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('failed to encode png');
      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/cardaily_share_${dateKey(widget.date)}.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: dateKey(widget.date)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.dailyDetailShareFailedMessage,
          ),
        ),
      );
    } finally {
      entry.remove();
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// 운행 기록 카드의 공유 아이콘을 탭했을 때: 목록의 작은 요약 카드가 아니라, 그
  /// 기록의 상세 화면(출발/도착지, 시각, 거리, 사진, 동행, 목적, 기분, 메모, 노래)을
  /// 전부 담은 별도 레이아웃을 오프스크린으로 그려서 캡처한다. 캡처한 요약 이미지와
  /// 사진 원본 파일들을 함께 공유 시트에 올려서, 받는 사람이 사진 원본도 개별로
  /// 저장할 수 있게 한다.
  Future<void> _shareDriveDetail(Drive drive) async {
    final driveId = drive.id;
    if (driveId == null || _sharingDriveIds.contains(driveId)) return;
    setState(() => _sharingDriveIds.add(driveId));

    final captureKey = GlobalKey();
    OverlayEntry? entryOverlay;
    try {
      for (final path in drive.photoPaths) {
        if (!mounted) return;
        await precacheImage(FileImage(File(path)), context);
      }
      if (!mounted) return;

      final overlay = Overlay.of(context);
      final width = MediaQuery.of(context).size.width;
      entryOverlay = OverlayEntry(
        builder:
            (ctx) => Positioned(
              left: 0,
              top: -20000,
              width: width,
              child: RepaintBoundary(
                key: captureKey,
                child: Material(
                  color: AppColors.background,
                  child: _buildShareDriveLayout(drive),
                ),
              ),
            ),
      );
      overlay.insert(entryOverlay);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = captureKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('detail capture boundary not found');
      }
      final image = await renderObject.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('failed to encode png');
      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final summaryFile = File(
        '${dir.path}/cardaily_share_detail_${dateKey(widget.date)}_$driveId.png',
      );
      await summaryFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(summaryFile.path),
            for (final path in drive.photoPaths) XFile(path),
          ],
          text: dateKey(widget.date),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.dailyDetailShareFailedMessage,
          ),
        ),
      );
    } finally {
      entryOverlay?.remove();
      if (mounted) setState(() => _sharingDriveIds.remove(driveId));
    }
  }

  /// [_shareDriveDetail]이 오프스크린으로 캡처할 상세 레이아웃. 사진이 여러 장일
  /// 때는 세로로 길게 나열하지 않고 3열 그리드로 배치해서 축소한다.
  Widget _buildShareDriveLayout(Drive drive) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateKey(widget.date),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          if (drive.routeSummary.isNotEmpty)
            Text(
              drive.routeSummary,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          if (drive.startTime != null || drive.endTime != null) ...[
            const SizedBox(height: 6),
            Text(
              '${drive.startTime ?? '--:--'} → ${drive.endTime ?? '--:--'}',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (drive.distanceKm != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.dailyDetailDistanceTagLabel(
                  drive.distanceKm!.toStringAsFixed(1),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.amberDark,
                ),
              ),
            ),
          ],
          if (drive.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 20),
            _ShareSectionTitle(l10n.recordInputSectionPhoto),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                const columns = 3;
                final tileSize =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final path in drive.photoPaths)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(path),
                          width: tileSize,
                          height: tileSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          _ShareSectionTitle(l10n.recordInputSectionCompanion),
          Text(
            CompanionTag.displayList(context, drive.companionTags),
            style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          _ShareSectionTitle(l10n.recordInputSectionPurpose),
          Text(
            drive.purposeTag.localizedLabel(context),
            style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          _ShareSectionTitle(l10n.recordInputSectionMood),
          Text(
            '${drive.moodTag.emoji} ${drive.moodTag.localizedLabel(context)}'
            '${drive.moodDetail != null ? ' · ${drive.moodDetail}' : ''}',
            style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
          ),
          if (drive.memo != null && drive.memo!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _ShareSectionTitle(l10n.recordInputSectionMemo),
            Text(
              drive.memo!,
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          if (drive.songTitle != null && drive.songTitle!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎵', style: TextStyle(fontSize: 17)),
                const SizedBox(width: 6),
                Text(
                  drive.songTitle!,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amberDark,
                  ),
                ),
              ],
            ),
          ],
        ],
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
          if (_sharing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              tooltip: AppLocalizations.of(context)!.dailyDetailShareTooltip,
              onPressed: showFab ? _shareDayAsImage : null,
              icon: const Icon(Icons.share_outlined),
            ),
          if (showFab)
            IconButton(
              tooltip: AppLocalizations.of(context)!.dailyDetailResetDayTooltip,
              onPressed: _resetDay,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: _buildBodyChildren(),
              ),
          Positioned(
            left: 16,
            bottom:
                16 +
                MediaQuery.of(context).padding.bottom +
                MediaQuery.of(context).viewInsets.bottom,
            child: FloatingActionButton(
              heroTag: 'dailyDetailShopFab',
              onPressed: _openShopFromDay,
              backgroundColor: AppColors.woodBrown,
              foregroundColor: Colors.white,
              tooltip: AppLocalizations.of(context)!.shopSideDishAction,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton:
          showFab
              ? FloatingActionButton(
                heroTag: 'dailyDetailAddRecordFab',
                onPressed: () => _addRecord(),
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add_rounded),
              )
              : null,
    );
  }
}

/// 그 날 병원 다녀온(또는 다녀올) 기록을 아래 운행 기록 카드와 같은 톤의
/// 심플한 카드로 보여준다. 탭하면 [PlanDetailScreen]으로 이동해서 상세 내용,
/// 수정 버튼, 그리고 (예약 날짜가 오늘보다 이후일 때만) D-DAY 카운트다운/
/// 리마인드/취소 액션을 볼 수 있다.
class _PlanRecordCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onTap;

  const _PlanRecordCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.sageBg,
              child: Text('🏥', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (plan.companionTag != null &&
                      plan.companionTag!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      plan.companionTag!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MiniTag(
                        text: plan.type.localizedLabel(context),
                        color: AppColors.sage,
                        bg: AppColors.sageBg,
                      ),
                    ],
                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPlanCta extends StatelessWidget {
  final VoidCallback onAdd;
  final bool isFuture;

  const _AddPlanCta({required this.onAdd, required this.isFuture});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              isFuture
                  ? l10n.dailyDetailAddPlanCtaFuture
                  : l10n.dailyDetailAddPlanCta,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
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
  final VoidCallback onShare;
  final VoidCallback onTapPhoto;
  final VoidCallback onTap;

  const _DriveTile({
    required this.drive,
    required this.onDelete,
    required this.onShare,
    required this.onTapPhoto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 카드 안에 이미 InkWell 링크(목적지 텍스트)가 중첩돼 있어서, 카드 전체를 또
    // InkWell/Material로 감싸면 탭 시 잉크 스플래시 애니메이션이 정리되는 도중
    // Navigator.push가 서브트리를 비활성화하면서 프레임워크 단언 실패로 크래시가
    // 날 수 있다. 카드 전체 탭은 스플래시 없는 GestureDetector로 처리한다.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DriveTileContent(drive: drive, onTapPhoto: onTapPhoto),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// [_DriveTile]에서 공유 이미지로 캡처되는 부분(썸네일 + 상세 내용)만 따로 뗀
/// 위젯. 삭제/공유 아이콘은 캡처 대상에서 빠져야 하므로 별도로 분리했다.
class _DriveTileContent extends StatelessWidget {
  final Drive drive;
  final VoidCallback onTapPhoto;

  const _DriveTileContent({required this.drive, required this.onTapPhoto});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final thumbnailPath =
        drive.photoPaths.isEmpty ? null : drive.photoPaths.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: thumbnailPath == null ? null : onTapPhoto,
          child:
              thumbnailPath == null
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
                onTap:
                    () => openShoppingSearch(
                      context,
                      drive.purposeTag.shopQuery(context),
                    ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MiniTag(
                    text: CompanionTag.displayList(
                      context,
                      drive.companionTags,
                    ),
                    color: AppColors.sage,
                    bg: AppColors.sageBg,
                  ),
                  _MiniTag(
                    text: drive.purposeTag.localizedLabel(context),
                    color: AppColors.route,
                    bg: AppColors.routeBg,
                  ),
                  _MiniTag(
                    text:
                        '${drive.moodTag.emoji} ${drive.moodTag.localizedLabel(context)}'
                        '${drive.moodDetail != null ? ' · ${drive.moodDetail}' : ''}',
                    color: AppColors.terracotta,
                    bg: AppColors.terracottaBg,
                  ),
                  if (drive.distanceKm != null)
                    _MiniTag(
                      text: l10n.dailyDetailDistanceTagLabel(
                        drive.distanceKm!.toStringAsFixed(1),
                      ),
                      color: AppColors.amberDark,
                      bg: AppColors.amberLight,
                    ),
                ],
              ),
              if (drive.memo != null && drive.memo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  drive.memo!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// [_DailyDetailScreenState._buildShareDriveLayout]에서 쓰는 섹션 제목.
class _ShareSectionTitle extends StatelessWidget {
  final String text;

  const _ShareSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.woodBrown,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${drive.routeSummary} · ${CompanionTag.displayList(context, drive.companionTags)} · '
            '${drive.moodTag.emoji} ${drive.moodTag.localizedLabel(context)}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnniversaryDayCard extends StatelessWidget {
  final Anniversary anniversary;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _AnniversaryDayCard({
    required this.anniversary,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                      l10n.dailyDetailAnniversaryTitle(
                        anniversary.emoji,
                        anniversary.title,
                      ),
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
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
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
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
