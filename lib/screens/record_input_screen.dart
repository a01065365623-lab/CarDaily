import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';
import '../models/companion_tag.dart';
import '../models/drive.dart';
import '../models/emotion_category.dart';
import '../models/purpose_tag.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import '../utils/photo_storage.dart';
import '../widgets/dashed_border_box.dart';

/// [RecordInputScreen]이 저장 완료 시 반환하는 결과. 호출한 화면(캘린더/일자 상세)에서
/// "관련 상품 보기" 스낵바를 띄울 때 [shopQuery]를 검색어로 쓴다.
class RecordSaveResult {
  final String shopQuery;

  const RecordSaveResult({required this.shopQuery});
}

/// 하루 운행 기록을 입력하는 화면. [date]에 저장된다.
class RecordInputScreen extends StatefulWidget {
  final DateTime date;

  const RecordInputScreen({super.key, required this.date});

  @override
  State<RecordInputScreen> createState() => _RecordInputScreenState();
}

class _RecordInputScreenState extends State<RecordInputScreen> {
  static const int _maxPhotos = 2;

  final _startPlaceController = TextEditingController();
  final _endPlaceController = TextEditingController();
  final _distanceController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final List<String> _photoPaths = [];

  final Set<CompanionTag> _companionChips = {};
  bool _companionIsCustom = false;
  final _companionCustomController = TextEditingController();

  PurposeTag _purposeTag = PurposeTag.drive;

  EmotionCategory _moodCategory = EmotionCategory.joy;
  bool _moodIsCustom = false;
  final _moodDetailController = TextEditingController();

  final _memoController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _startPlaceController.dispose();
    _endPlaceController.dispose();
    _distanceController.dispose();
    _companionCustomController.dispose();
    _moodDetailController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickPhotos() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.amberDark),
                title: Text(l10n.recordInputCameraOption),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.amberDark),
                title: Text(l10n.recordInputGalleryOption),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    final remaining = _maxPhotos - _photoPaths.length;
    if (remaining <= 0) return;

    final picked = source == ImageSource.camera
        ? await _pickSinglePhoto()
        : await _pickMultiplePhotos(remaining);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photoPaths.addAll(picked));
  }

  Future<List<String>> _pickSinglePhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
    if (file == null) return [];
    return [await copyImageToAppStorage(file.path)];
  }

  Future<List<String>> _pickMultiplePhotos(int remaining) async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (files.isEmpty) return [];
    final taken = files.take(remaining);
    final savedPaths = <String>[];
    for (final file in taken) {
      savedPaths.add(await copyImageToAppStorage(file.path));
    }
    return savedPaths;
  }

  Future<void> _removePhoto(int index) async {
    final path = _photoPaths[index];
    setState(() => _photoPaths.removeAt(index));
    await deleteImageFile(path);
  }

  List<String> get _companionTags {
    final tags = _companionChips.map((c) => c.label).toList();
    if (_companionIsCustom) {
      final custom = _companionCustomController.text.trim();
      if (custom.isNotEmpty) tags.add(custom);
    }
    return tags;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final startPlace = _startPlaceController.text.trim();
    final endPlace = _endPlaceController.text.trim();
    if (startPlace.isEmpty && endPlace.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.recordInputSnackbarNeedRoute)),
      );
      return;
    }
    setState(() => _saving = true);
    final drive = Drive.create(
      date: dateKey(widget.date),
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      startPlace: startPlace.isEmpty ? null : startPlace,
      endPlace: endPlace.isEmpty ? null : endPlace,
      distanceKm: double.tryParse(_distanceController.text.trim()),
      companionTags: _companionTags,
      purposeTag: _purposeTag,
      moodTag: _moodCategory,
      moodDetail: _moodIsCustom
          ? (_moodDetailController.text.trim().isEmpty ? null : _moodDetailController.text.trim())
          : null,
      memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
      photoPaths: _photoPaths,
    );
    await DatabaseHelper.instance.insertDrive(drive);
    if (!mounted) return;
    Navigator.of(context).pop(RecordSaveResult(shopQuery: _purposeTag.shopQuery(context)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.recordInputAppBarTitle(dateKey(widget.date))),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionTitle(l10n.recordInputSectionRoute),
          TextField(
            controller: _startPlaceController,
            decoration: InputDecoration(
              hintText: l10n.recordInputStartPlaceHint,
              prefixIcon: const Icon(Icons.trip_origin_rounded, color: AppColors.amberDark),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _endPlaceController,
            decoration: InputDecoration(
              hintText: l10n.recordInputEndPlaceHint,
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.amberDark),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.recordInputSectionTime),
          Row(
            children: [
              Expanded(
                child: _TimePickerBox(
                  label: l10n.recordInputStartTimeLabel,
                  time: _startTime,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimePickerBox(
                  label: l10n.recordInputEndTimeLabel,
                  time: _endTime,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.recordInputSectionDistance),
          TextField(
            controller: _distanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: l10n.recordInputDistanceHint,
              suffixText: 'km',
              prefixIcon: const Icon(Icons.route_outlined, color: AppColors.amberDark),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.recordInputSectionPhoto),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoPaths.length + (_photoPaths.length < _maxPhotos ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == _photoPaths.length) {
                  return DashedBorderBox(
                    size: 84,
                    color: AppColors.textSecondary,
                    onTap: _pickPhotos,
                    child: const Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 28),
                  );
                }
                final path = _photoPaths[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(path),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.woodBrown,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.recordInputSectionCompanion),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...CompanionTag.values.map((tag) {
                final selected = _companionChips.contains(tag);
                return FilterChip(
                  label: Text(tag.localizedLabel(context)),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _companionChips.add(tag);
                    } else {
                      _companionChips.remove(tag);
                    }
                  }),
                  selectedColor: AppColors.sage,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.sageBg,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                );
              }),
              FilterChip(
                label: Text(l10n.commonDirectInputChip),
                selected: _companionIsCustom,
                onSelected: (value) => setState(() => _companionIsCustom = value),
                selectedColor: AppColors.sage,
                labelStyle: TextStyle(
                  color: _companionIsCustom ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.sageBg,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
              ),
            ],
          ),
          if (_companionIsCustom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _companionCustomController,
              decoration: InputDecoration(
                hintText: l10n.recordInputCompanionCustomHint,
                isDense: true,
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(l10n.recordInputSectionPurpose),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PurposeTag.values.map((tag) {
              final selected = _purposeTag == tag;
              return ChoiceChip(
                label: Text(tag.localizedLabel(context)),
                selected: selected,
                onSelected: (_) => setState(() => _purposeTag = tag),
                selectedColor: AppColors.route,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.routeBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.recordInputSectionMood),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...EmotionCategory.values.map((category) {
                final selected = !_moodIsCustom && _moodCategory == category;
                return ChoiceChip(
                  label: Text('${category.emoji} ${category.localizedLabel(context)}'),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _moodCategory = category;
                    _moodIsCustom = false;
                    _moodDetailController.clear();
                  }),
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
              }),
              ChoiceChip(
                label: Text(l10n.commonDirectInputChip),
                selected: _moodIsCustom,
                onSelected: (_) => setState(() {
                  _moodIsCustom = true;
                  _moodCategory = EmotionCategory.none;
                }),
                selectedColor: AppColors.terracotta,
                labelStyle: TextStyle(
                  color: _moodIsCustom ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.terracottaBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
              ),
            ],
          ),
          if (_moodIsCustom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _moodDetailController,
              decoration: InputDecoration(
                hintText: l10n.recordInputMoodCustomHint,
                isDense: true,
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(l10n.recordInputSectionMemo),
          TextField(
            controller: _memoController,
            maxLength: 500,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: l10n.recordInputMemoHint,
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

class _TimePickerBox extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimePickerBox({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: AppColors.amberDark, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    time?.format(context) ?? '--:--',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
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
