import 'dart:io';

import 'package:flutter/material.dart';

/// 운행 기록에 첨부된 사진들을 전체화면으로 스와이프하며 보는 화면.
class PhotoGalleryScreen extends StatelessWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const PhotoGalleryScreen({super.key, required this.photoPaths, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photoPaths.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.file(File(photoPaths[index]), fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
