import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// [sourcePath]의 이미지를 앱 documents 디렉토리(`photos/`) 밑으로 복사하고,
/// 복사된 파일의 절대 경로를 반환한다.
Future<String> copyImageToAppStorage(String sourcePath) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final photosDir = Directory(p.join(docsDir.path, 'photos'));
  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }
  final ext = p.extension(sourcePath);
  final fileName = '${DateTime.now().microsecondsSinceEpoch}$ext';
  final destPath = p.join(photosDir.path, fileName);
  await File(sourcePath).copy(destPath);
  return destPath;
}

/// 존재하지 않아도 조용히 무시하고 파일을 지운다.
Future<void> deleteImageFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
