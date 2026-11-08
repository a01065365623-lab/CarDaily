import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/fuel_log.dart';
import '../theme/app_colors.dart';
import 'fuel_log_detail_screen.dart';
import 'fuel_log_input_screen.dart';

/// "기름 먹은 날" 기록 목록을 관리하는 화면. drives와 연결되지 않는 독립 주유 기록이다.
class FuelLogListScreen extends StatefulWidget {
  const FuelLogListScreen({super.key});

  @override
  State<FuelLogListScreen> createState() => _FuelLogListScreenState();
}

class _FuelLogListScreenState extends State<FuelLogListScreen> {
  List<FuelLog> _fuelLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getAllFuelLogs();
    if (!mounted) return;
    setState(() {
      _fuelLogs = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const FuelLogInputScreen()));
    if (saved == true) _load();
  }

  Future<void> _openDetail(FuelLog fuelLog) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FuelLogDetailScreen(fuelLog: fuelLog)),
    );
    _load();
  }

  Future<bool> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.fuelLogListDeleteDialogTitle),
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
    return confirmed ?? false;
  }

  Future<void> _delete(FuelLog fuelLog) async {
    if (fuelLog.id == null) return;
    await DatabaseHelper.instance.deleteFuelLog(fuelLog.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.fuelLogListSnackbarDeleted),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).languageCode;
    final costFormat = NumberFormat('#,##0', localeTag);
    final amountFormat = NumberFormat('#,##0.#', localeTag);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.fuelLogListAppBarTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _fuelLogs.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _fuelLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final fuelLog = _fuelLogs[index];
                  return Dismissible(
                    key: ValueKey(fuelLog.id ?? index),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade300,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (_) => _confirmDelete(),
                    onDismissed: (_) => _delete(fuelLog),
                    child: InkWell(
                      onTap: () => _openDetail(fuelLog),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Text('⛽', style: TextStyle(fontSize: 26)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        fuelLog.date,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${fuelLog.fuelType.localizedLabel(context)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.fuelLogListCostAmount(
                                      costFormat.format(fuelLog.cost),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (fuelLog.amount != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatAmount(
                                        context,
                                        fuelLog,
                                        amountFormat,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (fuelLog.memo != null &&
                                      fuelLog.memo!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      fuelLog.memo!,
                                      style: const TextStyle(
                                        fontSize: 13,
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
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

/// 연료 종류에 맞는 단위를 붙여 충전/주유량을 표시한다. '기타'처럼 단위가 없는
/// 경우 숫자만 보여준다.
String _formatAmount(
  BuildContext context,
  FuelLog fuelLog,
  NumberFormat amountFormat,
) {
  final formatted = amountFormat.format(fuelLog.amount);
  final unit = fuelLog.fuelType.unitLabel(context);
  return unit == null ? formatted : '$formatted $unit';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          AppLocalizations.of(context)!.fuelLogListEmptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
