import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/fuel_log.dart';
import '../theme/app_colors.dart';
import 'fuel_log_input_screen.dart';

/// 저장된 "기름 먹은 날" 기록 하나의 상세 화면. 입력했던 모든 필드를 읽기
/// 전용으로 보여주고, 상단 "수정" 버튼으로 [FuelLogInputScreen]을 수정 모드로
/// 열 수 있다.
class FuelLogDetailScreen extends StatefulWidget {
  final FuelLog fuelLog;

  const FuelLogDetailScreen({super.key, required this.fuelLog});

  @override
  State<FuelLogDetailScreen> createState() => _FuelLogDetailScreenState();
}

class _FuelLogDetailScreenState extends State<FuelLogDetailScreen> {
  late FuelLog _fuelLog = widget.fuelLog;
  bool _changed = false;

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FuelLogInputScreen(existingFuelLog: _fuelLog),
      ),
    );
    if (saved != true || _fuelLog.id == null) return;
    final all = await DatabaseHelper.instance.getAllFuelLogs();
    if (!mounted) return;
    final match = all.where((f) => f.id == _fuelLog.id);
    if (match.isEmpty) return;
    setState(() {
      _fuelLog = match.first;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).languageCode;
    final costFormat = NumberFormat('#,##0', localeTag);
    final amountFormat = NumberFormat('#,##0.#', localeTag);
    final unit = _fuelLog.fuelType.unitLabel(context);
    final amountLabel =
        unit == null
            ? l10n.fuelLogInputSectionAmountNoUnit
            : l10n.fuelLogInputSectionAmountWithUnit(unit);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_fuelLog.date),
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
            _DetailSectionTitle(l10n.fuelLogInputSectionFuelType),
            _DetailCard(
              child: Text(
                _fuelLog.fuelType.localizedLabel(context),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _DetailSectionTitle(l10n.fuelLogInputSectionCost),
            _DetailCard(
              child: Text(
                l10n.fuelLogListCostAmount(costFormat.format(_fuelLog.cost)),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (_fuelLog.amount != null) ...[
              const SizedBox(height: 20),
              _DetailSectionTitle(amountLabel),
              _DetailCard(
                child: Text(
                  unit == null
                      ? amountFormat.format(_fuelLog.amount)
                      : '${amountFormat.format(_fuelLog.amount)} $unit',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
            if (_fuelLog.memo != null && _fuelLog.memo!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _DetailSectionTitle(l10n.fuelLogInputSectionMemo),
              _DetailCard(
                child: Text(
                  _fuelLog.memo!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  final String text;

  const _DetailSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;

  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}
