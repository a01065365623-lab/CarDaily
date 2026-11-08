import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../db/database_helper.dart';
import '../models/companion_tag.dart';
import '../models/drive.dart';
import '../theme/app_colors.dart';
import 'photo_gallery_screen.dart';
import 'record_input_screen.dart';

/// 저장된 운행 기록 하나의 상세 화면. 입력했던 모든 필드를 읽기 전용으로
/// 보여주고, 상단 "수정" 버튼으로 [RecordInputScreen]을 수정 모드로 열 수 있다.
class DriveDetailScreen extends StatefulWidget {
  final Drive drive;

  const DriveDetailScreen({super.key, required this.drive});

  @override
  State<DriveDetailScreen> createState() => _DriveDetailScreenState();
}

class _DriveDetailScreenState extends State<DriveDetailScreen> {
  late Drive _drive = widget.drive;
  bool _changed = false;

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => RecordInputScreen(
              date: DateTime.parse(_drive.date),
              existingDrive: _drive,
            ),
      ),
    );
    if (saved != true || _drive.id == null) return;
    final updated = await DatabaseHelper.instance.getDrivesForDate(_drive.date);
    if (!mounted) return;
    final match = updated.where((d) => d.id == _drive.id);
    if (match.isEmpty) return;
    setState(() {
      _drive = match.first;
      _changed = true;
    });
  }

  void _openGallery(int initialIndex) {
    if (_drive.photoPaths.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PhotoGalleryScreen(
              photoPaths: _drive.photoPaths,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_drive.date),
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
            if (_drive.routeSummary.isNotEmpty) ...[
              _DetailSectionTitle(l10n.recordInputSectionRoute),
              _DetailCard(
                child: Text(
                  _drive.routeSummary,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_drive.startTime != null || _drive.endTime != null) ...[
              _DetailSectionTitle(l10n.recordInputSectionTime),
              _DetailCard(
                child: Text(
                  '${_drive.startTime ?? '--:--'} → ${_drive.endTime ?? '--:--'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_drive.distanceKm != null) ...[
              _DetailSectionTitle(l10n.recordInputSectionDistance),
              _DetailCard(
                child: Text(
                  '${_drive.distanceKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_drive.photoPaths.isNotEmpty) ...[
              _DetailSectionTitle(l10n.recordInputSectionPhoto),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _drive.photoPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _openGallery(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_drive.photoPaths[index]),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            _DetailSectionTitle(l10n.recordInputSectionCompanion),
            _DetailCard(
              child: Text(
                CompanionTag.displayList(context, _drive.companionTags),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _DetailSectionTitle(l10n.recordInputSectionPurpose),
            _DetailCard(
              child: Text(
                _drive.purposeTag.localizedLabel(context),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _DetailSectionTitle(l10n.recordInputSectionMood),
            _DetailCard(
              child: Text(
                '${_drive.moodTag.emoji} ${_drive.moodTag.localizedLabel(context)}'
                '${_drive.moodDetail != null ? ' · ${_drive.moodDetail}' : ''}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (_drive.memo != null && _drive.memo!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _DetailSectionTitle(l10n.recordInputSectionMemo),
              _DetailCard(
                child: Text(
                  _drive.memo!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (_drive.songTitle != null && _drive.songTitle!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _DetailSectionTitle(l10n.recordInputSectionSong),
              _DetailCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: AppColors.amberDark,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _drive.songTitle!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
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
