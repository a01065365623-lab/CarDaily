import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../db/database_helper.dart';
import '../models/fuel_log.dart';
import '../models/fuel_type.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';

/// "기름 먹은 날" 기록을 등록하거나([existingFuelLog]이 null) 수정하는
/// ([existingFuelLog]이 있음) 화면. drives와 연결되지 않는 독립 기록이라 오늘 또는
/// 과거 날짜만 선택할 수 있다.
class FuelLogInputScreen extends StatefulWidget {
  final FuelLog? existingFuelLog;

  const FuelLogInputScreen({super.key, this.existingFuelLog});

  @override
  State<FuelLogInputScreen> createState() => _FuelLogInputScreenState();
}

class _FuelLogInputScreenState extends State<FuelLogInputScreen> {
  late DateTime _date =
      widget.existingFuelLog != null
          ? DateTime.parse(widget.existingFuelLog!.date)
          : _today();
  late FuelType _fuelType =
      widget.existingFuelLog?.fuelType ?? FuelType.gasoline;
  late final _amountController = TextEditingController(
    text: widget.existingFuelLog?.amount?.toString() ?? '',
  );
  late final _costController = TextEditingController(
    text: widget.existingFuelLog?.cost.toString() ?? '',
  );
  late final _memoController = TextEditingController(
    text: widget.existingFuelLog?.memo ?? '',
  );
  bool _saving = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _costController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final cost = double.tryParse(_costController.text.trim());
    if (cost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fuelLogInputSnackbarNeedCost)),
      );
      return;
    }
    final amountText = _amountController.text.trim();
    final amount = amountText.isEmpty ? null : double.tryParse(amountText);
    setState(() => _saving = true);
    try {
      final existing = widget.existingFuelLog;
      if (existing != null) {
        final updated = FuelLog(
          id: existing.id,
          date: dateKey(_date),
          fuelType: _fuelType,
          amount: amount,
          cost: cost,
          memo:
              _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
          createdAt: existing.createdAt,
        );
        await DatabaseHelper.instance.updateFuelLog(updated);
      } else {
        final fuelLog = FuelLog.create(
          date: dateKey(_date),
          fuelType: _fuelType,
          amount: amount,
          cost: cost,
          memo:
              _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
        );
        await DatabaseHelper.instance.insertFuelLog(fuelLog);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.fuelLogInputSnackbarSaveFailed(e.toString())),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unit = _fuelType.unitLabel(context);
    final amountLabel =
        unit == null
            ? l10n.fuelLogInputSectionAmountNoUnit
            : l10n.fuelLogInputSectionAmountWithUnit(unit);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.fuelLogInputAppBarTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionTitle(l10n.fuelLogInputSectionDate),
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
                  const Icon(
                    Icons.local_gas_station_rounded,
                    color: AppColors.amberDark,
                  ),
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
          _SectionTitle(l10n.fuelLogInputSectionCost),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              hintText: l10n.fuelLogInputCostHint,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.fuelLogInputSectionFuelType),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                FuelType.values.map((type) {
                  final selected = _fuelType == type;
                  return ChoiceChip(
                    label: Text(type.localizedLabel(context)),
                    selected: selected,
                    onSelected: (_) => setState(() => _fuelType = type),
                    selectedColor: AppColors.fuelGold,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.amberLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionTitle(amountLabel),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              hintText: l10n.fuelLogInputAmountHint,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.fuelLogInputSectionMemo),
          TextField(
            controller: _memoController,
            maxLength: 300,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.fuelLogInputMemoHint,
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
                        l10n.fuelLogInputSaveButton,
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
