import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/companion_tag.dart';
import '../models/drive.dart';
import '../models/emotion_category.dart';
import '../models/fuel_log.dart';
import '../models/fuel_type.dart';
import '../models/plan.dart';
import '../models/plan_type.dart';
import '../models/purpose_tag.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';

enum _StatsPeriod { weekly, monthly }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // 기름 먹은 날 월별 추이는 주/월 기간 토글과 무관하게 항상 최근 6개월을 보여준다.
  static const int _fuelTrendMonths = 6;

  _StatsPeriod _period = _StatsPeriod.weekly;
  List<Drive> _drives = [];
  List<FuelLog> _fuelLogs = [];
  List<Plan> _plans = [];
  bool _loading = true;

  int get _windowDays => _period == _StatsPeriod.weekly ? 7 : 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final today = DateTime.now();
    final from = today.subtract(Duration(days: _windowDays - 1));
    final drives = await DatabaseHelper.instance.getDrivesForRange(dateKey(from), dateKey(today));
    final fuelLogs = await DatabaseHelper.instance.getAllFuelLogs();
    final plans = await DatabaseHelper.instance.getAllPlans();
    if (!mounted) return;
    setState(() {
      _drives = drives;
      _fuelLogs = fuelLogs;
      _plans = plans;
      _loading = false;
    });
  }

  /// 최근 [_fuelTrendMonths]개월(이번 달 포함)을 0으로 빈 달까지 채워 반환한다.
  List<_MonthStat> _fuelMonthlyStats() {
    final now = DateTime.now();
    final months = [
      for (var i = _fuelTrendMonths - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];
    final byMonth = {
      for (final m in months) _monthKey(m): _MonthStat(month: m, totalCost: 0, count: 0),
    };
    for (final log in _fuelLogs) {
      final date = DateTime.parse(log.date);
      final key = _monthKey(DateTime(date.year, date.month, 1));
      final existing = byMonth[key];
      if (existing == null) continue;
      byMonth[key] = _MonthStat(
        month: existing.month,
        totalCost: existing.totalCost + log.cost,
        count: existing.count + 1,
      );
    }
    return [for (final m in months) byMonth[_monthKey(m)]!];
  }

  String _monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

  Map<FuelType, ({double totalCost, int count})> _fuelTypeStats() {
    final map = {for (final t in FuelType.values) t: (totalCost: 0.0, count: 0)};
    for (final log in _fuelLogs) {
      final existing = map[log.fuelType]!;
      map[log.fuelType] = (totalCost: existing.totalCost + log.cost, count: existing.count + 1);
    }
    return map;
  }

  Map<PlanType, int> _planTypeCounts() {
    final map = {for (final t in PlanType.values) t: 0};
    for (final plan in _plans) {
      map[plan.type] = (map[plan.type] ?? 0) + 1;
    }
    return map;
  }

  /// [_plans]는 date DESC로 정렬되어 있으므로 첫 항목이 가장 최근(또는 가장 가까운) 날짜다.
  String? get _lastVisitDate => _plans.isEmpty ? null : _plans.first.date;

  void _onPeriodChanged(_StatsPeriod period) {
    setState(() => _period = period);
    _load();
  }

  /// 기간 내 날짜별 [기록 건수, 거리 합계]를 0으로 빈 날짜까지 채워 반환한다.
  List<_DayStat> _dailyStats() {
    final today = DateTime.now();
    final from = today.subtract(Duration(days: _windowDays - 1));
    final byDate = <String, _DayStat>{};
    for (var i = 0; i < _windowDays; i++) {
      final d = from.add(Duration(days: i));
      byDate[dateKey(d)] = _DayStat(date: d, count: 0, distanceKm: 0);
    }
    for (final drive in _drives) {
      final existing = byDate[drive.date];
      if (existing == null) continue;
      byDate[drive.date] = _DayStat(
        date: existing.date,
        count: existing.count + 1,
        distanceKm: existing.distanceKm + (drive.distanceKm ?? 0),
      );
    }
    final list = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Map<String, int> _companionCounts() {
    final map = <String, int>{};
    for (final drive in _drives) {
      for (final tag in drive.companionTags) {
        map[tag] = (map[tag] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<PurposeTag, int> _purposeCounts() {
    final map = {for (final t in PurposeTag.values) t: 0};
    for (final drive in _drives) {
      map[drive.purposeTag] = (map[drive.purposeTag] ?? 0) + 1;
    }
    return map;
  }

  Map<EmotionCategory, int> _moodCounts() {
    final map = {for (final t in EmotionCategory.values) t: 0};
    for (final drive in _drives) {
      map[drive.moodTag] = (map[drive.moodTag] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dailyStats = _dailyStats();
    final companionCounts = _companionCounts();
    final purposeCounts = _purposeCounts();
    final moodCounts = _moodCounts();
    final total = _drives.length;
    final fuelMonthlyStats = _fuelMonthlyStats();
    final fuelTypeStats = _fuelTypeStats();
    final planTypeCounts = _planTypeCounts();
    final planTotal = _plans.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.statsAppBarTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _PeriodToggle(period: _period, onChanged: _onPeriodChanged),
                const SizedBox(height: 20),
                if (total == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        l10n.statsEmptyMessage,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else ...[
                  _ChartCard(
                    title: l10n.statsChartFrequencyTitle,
                    child: SizedBox(height: 180, child: _FrequencyBarChart(stats: dailyStats)),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: l10n.statsChartDistanceTrendTitle,
                    child: SizedBox(height: 180, child: _DistanceLineChart(stats: dailyStats)),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: l10n.statsChartCompanionTitle,
                    child: _CompanionPieChart(counts: companionCounts, total: total),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: l10n.statsChartPurposeTitle,
                    child: _PurposeList(counts: purposeCounts, total: total),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: l10n.statsChartMoodTitle,
                    child: _MoodList(counts: moodCounts, total: total),
                  ),
                ],
                const SizedBox(height: 16),
                _ChartCard(
                  title: l10n.statsChartFuelCostTitle,
                  child: SizedBox(height: 160, child: _FuelCostBarChart(stats: fuelMonthlyStats)),
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: l10n.statsChartFuelCountTitle,
                  child: SizedBox(height: 160, child: _FuelCountBarChart(stats: fuelMonthlyStats)),
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: l10n.statsChartFuelByTypeTitle,
                  child: _FuelTypeList(stats: fuelTypeStats),
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: l10n.statsChartHospitalTitle,
                  child: _HospitalVisitSummary(
                    visitCount: planTotal,
                    lastVisitDate: _lastVisitDate,
                    typeCounts: planTypeCounts,
                    total: planTotal,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MonthStat {
  final DateTime month;
  final double totalCost;
  final int count;

  _MonthStat({required this.month, required this.totalCost, required this.count});
}

class _DayStat {
  final DateTime date;
  final int count;
  final double distanceKm;

  _DayStat({required this.date, required this.count, required this.distanceKm});
}

class _PeriodToggle extends StatelessWidget {
  final _StatsPeriod period;
  final ValueChanged<_StatsPeriod> onChanged;

  const _PeriodToggle({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: _StatsPeriod.values.map((p) {
        final selected = p == period;
        final label = p == _StatsPeriod.weekly ? l10n.statsPeriodWeekly : l10n.statsPeriodMonthly;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Center(child: Text(label)),
              selected: selected,
              onSelected: (_) => onChanged(p),
              selectedColor: AppColors.amber,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.woodBrownLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide.none,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FrequencyBarChart extends StatelessWidget {
  final List<_DayStat> stats;

  const _FrequencyBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.fold<int>(1, (m, s) => s.count > m ? s.count : m);
    final showEveryNth = stats.length > 14 ? (stats.length / 7).ceil() : 1;
    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                if (index % showEveryNth != 0) return const SizedBox.shrink();
                final d = stats[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${d.month}/${d.day}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < stats.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stats[i].count.toDouble(),
                  color: AppColors.amber,
                  width: stats.length > 14 ? 4 : 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DistanceLineChart extends StatelessWidget {
  final List<_DayStat> stats;

  const _DistanceLineChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final showEveryNth = stats.length > 14 ? (stats.length / 7).ceil() : 1;
    final maxY = stats.fold<double>(1, (m, s) => s.distanceKm > m ? s.distanceKm : m);
    return LineChart(
      LineChartData(
        maxY: maxY * 1.2,
        minY: 0,
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                if (index % showEveryNth != 0) return const SizedBox.shrink();
                final d = stats[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${d.month}/${d.day}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < stats.length; i++)
                FlSpot(i.toDouble(), stats[i].distanceKm),
            ],
            isCurved: true,
            color: AppColors.route,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.routeBg),
          ),
        ],
      ),
    );
  }
}

class _CompanionPieChart extends StatelessWidget {
  final Map<String, int> counts;
  final int total;

  const _CompanionPieChart({required this.counts, required this.total});

  static const List<Color> _palette = [
    AppColors.amber,
    AppColors.sage,
    AppColors.terracotta,
    AppColors.woodBrown,
    AppColors.amberDark,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(AppLocalizations.of(context)!.statsNoDataLabel, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    final tagTotal = entries.fold<int>(0, (sum, e) => sum + e.value);
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _palette[i % _palette.length],
                    radius: 32,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${CompanionTag.display(context, entries[i].key)} ${(entries[i].value / tagTotal * 100).round()}%',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurposeList extends StatelessWidget {
  final Map<PurposeTag, int> counts;
  final int total;

  const _PurposeList({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(l10n.statsNoDataLabel, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    e.key.localizedLabel(context),
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: e.value / total,
                      minHeight: 10,
                      backgroundColor: AppColors.routeBg,
                      valueColor: const AlwaysStoppedAnimation(AppColors.route),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.statsTimesCount(e.value),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MoodList extends StatelessWidget {
  final Map<EmotionCategory, int> counts;
  final int total;

  const _MoodList({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(l10n.statsNoDataLabel, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    '${e.key.emoji} ${e.key.localizedLabel(context)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: e.value / total,
                      minHeight: 10,
                      backgroundColor: AppColors.terracottaBg,
                      valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.statsTimesCount(e.value),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FuelCostBarChart extends StatelessWidget {
  final List<_MonthStat> stats;

  const _FuelCostBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).languageCode;
    final maxY = stats.fold<double>(1, (m, s) => s.totalCost > m ? s.totalCost : m);
    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.MMM(localeTag).format(stats[index].month),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < stats.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stats[i].totalCost,
                  color: AppColors.fuelGold,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FuelCountBarChart extends StatelessWidget {
  final List<_MonthStat> stats;

  const _FuelCountBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).languageCode;
    final maxCount = stats.fold<int>(1, (m, s) => s.count > m ? s.count : m);
    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.MMM(localeTag).format(stats[index].month),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < stats.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stats[i].count.toDouble(),
                  color: AppColors.amberDark,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FuelTypeList extends StatelessWidget {
  final Map<FuelType, ({double totalCost, int count})> stats;

  const _FuelTypeList({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).languageCode;
    final costFormat = NumberFormat('#,##0', localeTag);
    final entries = stats.entries.where((e) => e.value.count > 0).toList()
      ..sort((a, b) => b.value.totalCost.compareTo(a.value.totalCost));
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(l10n.statsNoDataLabel, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    final costTotal = entries.fold<double>(0, (sum, e) => sum + e.value.totalCost);
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    e.key.localizedLabel(context),
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: costTotal == 0 ? 0 : e.value.totalCost / costTotal,
                      minHeight: 10,
                      backgroundColor: AppColors.amberLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.fuelGold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.fuelLogListCostAmount(costFormat.format(e.value.totalCost))} · ${l10n.statsTimesCount(e.value.count)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HospitalVisitSummary extends StatelessWidget {
  final int visitCount;
  final String? lastVisitDate;
  final Map<PlanType, int> typeCounts;
  final int total;

  const _HospitalVisitSummary({
    required this.visitCount,
    required this.lastVisitDate,
    required this.typeCounts,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).languageCode;
    final lastVisit = lastVisitDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _HospitalSummaryStat(
                label: l10n.statsHospitalVisitCountLabel,
                value: l10n.statsTimesCount(visitCount),
              ),
            ),
            Expanded(
              child: _HospitalSummaryStat(
                label: l10n.statsHospitalLastVisitLabel,
                value: lastVisit == null
                    ? l10n.statsHospitalNoVisitLabel
                    : DateFormat.yMMMd(localeTag).format(DateTime.parse(lastVisit)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.statsHospitalTypeDistributionLabel,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        _PlanTypeList(counts: typeCounts, total: total),
      ],
    );
  }
}

class _HospitalSummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _HospitalSummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _PlanTypeList extends StatelessWidget {
  final Map<PlanType, int> counts;
  final int total;

  const _PlanTypeList({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(l10n.statsNoDataLabel, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    e.key.localizedLabel(context),
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: e.value / total,
                      minHeight: 10,
                      backgroundColor: AppColors.terracottaBg,
                      valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.statsTimesCount(e.value),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
