import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:gal/gal.dart';

/// 운행 기록에 첨부된 사진들을 전체화면으로 스와이프하며 보는 화면.
class PhotoGalleryScreen extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const PhotoGalleryScreen({
    super.key,
    required this.photoPaths,
    this.initialIndex = 0,
  });

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  late int _currentIndex = widget.initialIndex;
  bool _downloading = false;

  /// 현재 보고 있는 사진을 기기 갤러리에 저장한다. 저장 권한이 없으면 먼저 요청한다.
  Future<void> _downloadCurrentPhoto() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      var hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!hasAccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.photoGalleryDownloadPermissionDeniedMessage),
          ),
        );
        return;
      }
      await Gal.putImage(widget.photoPaths[_currentIndex], album: 'CarDaily');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.photoGalleryDownloadSuccessMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.photoGalleryDownloadFailedMessage)),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_downloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              tooltip: l10n.photoGalleryDownloadTooltip,
              onPressed: _downloadCurrentPhoto,
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.photoPaths.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.file(
                File(widget.photoPaths[index]),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
