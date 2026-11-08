import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

import '../db/database_helper.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import '../utils/shop_query.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/shop_link_sheet.dart';
import 'anniversary_list_screen.dart';
import 'daily_detail_screen.dart';
import 'fuel_log_input_screen.dart';
import 'plan_input_screen.dart';
import 'record_input_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeCalendarScreen extends StatefulWidget {
  const HomeCalendarScreen({super.key});

  @override
  State<HomeCalendarScreen> createState() => _HomeCalendarScreenState();
}

class _HomeCalendarScreenState extends State<HomeCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  /// 현재 보이는 달 범위 안에서 실제 운행 기록이 있는 날짜(yyyy-MM-dd) 집합. 채워진 점으로 표시한다.
  Set<String> _loggedDates = {};

  /// 병원 예약이 잡혀 있는 날짜 중, 이미 지났거나 오늘인 날짜(다녀온 기록으로
  /// 취급). 채워진 점으로 표시한다.
  Set<String> _pastPlannedDates = {};

  /// 병원 예약이 잡혀 있는 날짜 중, 아직 오늘보다 이후(미래)인 날짜(예약 대기
  /// 중). 테두리만 있는 점으로 표시한다.
  Set<String> _futurePlannedDates = {};

  /// 현재 보이는 달 범위 안에서 "기름 먹은 날" 기록이 있는 날짜 집합. 독립 아이콘(⛽)으로 표시한다.
  Set<String> _fuelLoggedDates = {};

  /// "MM-DD" → 이모지. 매년 반복되는 기념일/마일스톤이라 달과 무관하게 한 번만 불러와 둔다.
  Map<String, String> _recurringAnniversaryEmojiByMonthDay = {};

  /// "yyyy-MM-dd" → 이모지. 특정 연도에만 표시되는 1회성 기념일(여행 등).
  Map<String, String> _oneOffAnniversaryEmojiByDate = {};

  String? _vehicleNickname;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMarkersForMonth(_focusedMonth);
    _loadAnniversaries();
    _loadVehicleNickname();
  }

  Future<void> _loadMarkersForMonth(DateTime month) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final from = dateKey(firstDay);
    final to = dateKey(lastDay);
    final logged = await DatabaseHelper.instance.getLoggedDatesForRange(
      from,
      to,
    );
    final planned = await DatabaseHelper.instance.getPlannedDatesForRange(
      from,
      to,
    );
    final fuelLogged = await DatabaseHelper.instance.getFuelLogDatesForRange(
      from,
      to,
    );
    // 오늘(포함)까지는 "다녀온 기록"으로, 오늘보다 이후는 "아직 남은 예약"으로
    // 구분한다. 문자열 비교로도 날짜 순서가 그대로 유지되는 yyyy-MM-dd
    // 포맷이라 DateTime 파싱 없이 바로 비교할 수 있다.
    final todayKey = dateKey(DateTime.now());
    final pastPlanned =
        planned.where((d) => d.compareTo(todayKey) <= 0).toSet();
    final futurePlanned =
        planned.where((d) => d.compareTo(todayKey) > 0).toSet();
    if (!mounted) return;
    setState(() {
      _loggedDates = logged;
      _pastPlannedDates = pastPlanned;
      _futurePlannedDates = futurePlanned;
      _fuelLoggedDates = fuelLogged;
    });
  }

  Future<void> _loadAnniversaries() async {
    final list = await DatabaseHelper.instance.getAllAnniversaries();
    if (!mounted) return;
    setState(() {
      _recurringAnniversaryEmojiByMonthDay = {
        for (final a in list)
          if (a.isRecurring) a.date: a.emoji,
      };
      _oneOffAnniversaryEmojiByDate = {
        for (final a in list)
          if (!a.isRecurring) a.date: a.emoji,
      };
    });
  }

  Future<void> _loadVehicleNickname() async {
    final nickname = await SettingsService.getVehicleNickname();
    if (!mounted) return;
    setState(() => _vehicleNickname = nickname);
  }

  Future<void> _openAnniversaries() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AnniversaryListScreen()));
    _loadAnniversaries();
  }

  Future<void> _openFuelLogInput() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const FuelLogInputScreen()));
    if (saved == true) _loadMarkersForMonth(_focusedMonth);
  }

  Future<void> _openHospitalVisitInput() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => PlanInputScreen(initialDate: _selectedDay ?? DateTime.now()),
      ),
    );
    if (saved == true) _loadMarkersForMonth(_focusedMonth);
  }

  Future<void> _openDailyDetail(DateTime day) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DailyDetailScreen(date: day)));
    _loadMarkersForMonth(_focusedMonth);
    _loadAnniversaries();
  }

  Future<void> _openRecordInput() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordInputScreen(date: _selectedDay ?? DateTime.now()),
      ),
    );
    _loadMarkersForMonth(_focusedMonth);
    if (!mounted || result != true) return;
    showRecordSavedSnackbar(context);
  }

  /// 좌측 하단 쇼핑 FAB의 동작. 일자 상세 화면의 좌측 FAB와 동일하게, 선택된
  /// 날짜에 맞는 검색어로 쇼핑 링크를 연다.
  Future<void> _openShopForSelectedDay() async {
    final date = _selectedDay ?? DateTime.now();
    final query = await resolveShopQueryForDate(context, date);
    if (!mounted) return;
    await openShoppingSearch(context, query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).languageCode;
    final nickname = _vehicleNickname;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          nickname == null
              ? l10n.homeCalendarAppBarTitle
              : l10n.homeCalendarAppBarTitleWithNickname(nickname),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cake_outlined),
            tooltip: l10n.homeCalendarAnniversaryTooltip,
            onPressed: _openAnniversaries,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: l10n.homeCalendarStatsTooltip,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const StatsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.homeCalendarSettingsTooltip,
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadVehicleNickname();
            },
          ),
        ],
      ),
      // 고정 높이 위젯(배너+캘린더 카드+안내문)을 Column에 그대로 쌓으면, 화면이
      // 낮아지는 상황(예: 멀티윈도우 분할화면, 시스템 글자 크기 확대)에서 남는 공간이
      // 모자라 하단이 잘려나가며 "BOTTOM OVERFLOWED" 오류가 난다. 그런 상황에서도
      // 잘리지 않고 스크롤되도록 SingleChildScrollView로 감싼다.
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // 타이틀(앱바) 바로 아래에 배너를 둔다. 하단에 두면 화면 크기에 따라
                // FAB("오늘의 운행" 버튼)와 겹칠 수 있어, 겹칠 일이 없는 상단에 고정 배치한다.
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Center(child: BannerAdWidget()),
                ),
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  color: AppColors.cardBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  // table_calendar는 기본적으로 콘텐츠에 맞춰 스스로 높이를 재는데,
                  // 그 계산이 프레임 하나 정도 늦게 확정되는 순간이 있어 디버그
                  // 모드에서 "BOTTOM OVERFLOWED" 경고가 스친다(릴리즈 빌드에는 안
                  // 나타남). shouldFillViewport로 아래 SizedBox가 주는 고정 높이를
                  // 그대로 채우게 하면, 자체 측정을 안 하니 그 문제 자체가 없어진다.
                  // 420 = 헤더+요일行+6주(52px×6) 기준 여유 있게 잡은 값.
                  child: SizedBox(
                    height: 420,
                    child: TableCalendar(
                      locale: localeTag,
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2100, 12, 31),
                      focusedDay: _focusedMonth,
                      selectedDayPredicate:
                          (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedMonth = focused;
                        });
                        _openDailyDetail(selected);
                      },
                      onPageChanged: (focused) {
                        _focusedMonth = focused;
                        _loadMarkersForMonth(focused);
                      },
                      onFormatChanged: (_) {},
                      calendarFormat: CalendarFormat.month,
                      // 이 달이 5주짜리인지 6주짜리인지에 따라 table_calendar가 카드 높이를
                      // 애니메이션으로 다시 계산하는데, 그 전환 도중 순간적으로(약 1초)
                      // "BOTTOM OVERFLOWED" 경고가 뜨는 문제가 있었다. 항상 6주 높이로
                      // 고정해서 5→6주 전환 자체가 없도록 한다.
                      sixWeekMonthsEnforced: true,
                      shouldFillViewport: true,
                      availableCalendarFormats: const {
                        CalendarFormat.month: '월',
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 18,
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
                        markersAlignment: Alignment.bottomCenter,
                        markersAutoAligned: false,
                        markerMargin: EdgeInsets.only(top: 4),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final key = dateKey(day);
                          final hasLog = _loggedDates.contains(key);
                          final hasPastPlan = _pastPlannedDates.contains(key);
                          final hasFuturePlan = _futurePlannedDates.contains(
                            key,
                          );
                          final hasFuelLog = _fuelLoggedDates.contains(key);
                          final anniversaryEmoji =
                              _oneOffAnniversaryEmojiByDate[key] ??
                              _recurringAnniversaryEmojiByMonthDay[monthDayKey(
                                day,
                              )];
                          if (!hasLog &&
                              !hasPastPlan &&
                              !hasFuturePlan &&
                              !hasFuelLog &&
                              anniversaryEmoji == null) {
                            return null;
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (anniversaryEmoji != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 1.5),
                                  child: Text(
                                    anniversaryEmoji,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ),
                              if (hasFuelLog)
                                const Padding(
                                  padding: EdgeInsets.only(right: 1.5),
                                  child: Text(
                                    '⛽',
                                    style: TextStyle(fontSize: 9),
                                  ),
                                ),
                              if (hasLog)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.calendarDot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasPastPlan)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.sage,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasFuturePlan)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.sage,
                                      width: 1.3,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      onHeaderTapped: (_) {},
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.homeCalendarHintText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendDot(
                            filled: true,
                            color: AppColors.calendarDot,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.homeCalendarLegendLogged,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendDot(filled: true, color: AppColors.sage),
                          const SizedBox(width: 6),
                          Text(
                            l10n.homeCalendarLegendPlanVisited,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendDot(filled: false, color: AppColors.sage),
                          const SizedBox(width: 6),
                          Text(
                            l10n.homeCalendarLegendPlanned,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⛽', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 6),
                          Text(
                            l10n.homeCalendarLegendFuel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // FAB 3개(기름 먹은 날/병원 간 날/오늘의 운행)가 세로로 쌓여 있어
                // 마지막 내용(범례)을 가리지 않도록 그만큼 여유 공간을 넉넉히 둔다.
                // Spacer는 스크롤 가능한(높이가 무한대인) Column 안에서는 쓸 수 없어
                // 고정 크기 SizedBox로 대체한다.
                const SizedBox(height: 220),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom:
                16 +
                MediaQuery.of(context).padding.bottom +
                MediaQuery.of(context).viewInsets.bottom,
            child: FloatingActionButton(
              heroTag: 'calendarShopFab',
              onPressed: _openShopForSelectedDay,
              backgroundColor: AppColors.woodBrown,
              foregroundColor: Colors.white,
              tooltip: l10n.shopSideDishAction,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fuelLogInputFab',
            onPressed: _openFuelLogInput,
            backgroundColor: AppColors.fuelGold,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.local_gas_station_rounded, size: 20),
            label: Text(l10n.homeCalendarFuelLogTooltip),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'hospitalVisitInputFab',
            onPressed: _openHospitalVisitInput,
            backgroundColor: AppColors.terracotta,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.local_hospital_rounded, size: 20),
            label: Text(l10n.homeCalendarHospitalVisitFabLabel),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'recordInputFab',
            onPressed: _openRecordInput,
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.directions_car_filled_rounded, size: 20),
            label: Text(l10n.homeCalendarFabLabel),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final bool filled;
  final Color color;

  const _LegendDot({required this.filled, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: filled ? null : Border.all(color: color, width: 1.3),
      ),
    );
  }
}
