import 'dart:convert';

import 'emotion_category.dart';
import 'purpose_tag.dart';

/// 하루 중 한 번의 운행 기록. 차계부가 아니라 "누구와 어디로 왜 운행했는지"를
/// 남기는 감성 다이어리라서, 정비 이력 같은 차량 관리 데이터는 다루지 않는다.
class Drive {
  final int? id;
  final String date; // yyyy-MM-dd
  final String? startTime; // HH:mm
  final String? endTime;
  final String? startPlace;
  final String? endPlace;
  final double? distanceKm;

  /// 함께 운행한 사람 태그(칩에서 고른 값 또는 직접입력 텍스트). 여러 명 선택 가능.
  final List<String> companionTags;
  final PurposeTag purposeTag;
  final EmotionCategory moodTag;
  final String? moodDetail;
  final String? memo;

  /// 앱 내부 저장소에 복사된 사진 경로. 최대 3장.
  final List<String> photoPaths;

  /// 입력 화면에서 유튜브로 찾아본 노래 제목(선택). 상세 화면에서 그대로 다시
  /// 볼 수 있도록 저장해 둔다.
  final String? songTitle;

  /// 입력 화면 '맛집·가볼만한곳'에 적은 메모(선택). 유튜브 검색어로도 쓰인다.
  final String? placesNote;
  final DateTime createdAt;

  Drive({
    this.id,
    required this.date,
    this.startTime,
    this.endTime,
    this.startPlace,
    this.endPlace,
    this.distanceKm,
    required this.companionTags,
    required this.purposeTag,
    required this.moodTag,
    this.moodDetail,
    this.memo,
    required this.photoPaths,
    this.songTitle,
    this.placesNote,
    required this.createdAt,
  });

  factory Drive.create({
    int? id,
    required String date,
    String? startTime,
    String? endTime,
    String? startPlace,
    String? endPlace,
    double? distanceKm,
    required List<String> companionTags,
    required PurposeTag purposeTag,
    required EmotionCategory moodTag,
    String? moodDetail,
    String? memo,
    required List<String> photoPaths,
    String? songTitle,
    String? placesNote,
    DateTime? createdAt,
  }) {
    return Drive(
      id: id,
      date: date,
      startTime: startTime,
      endTime: endTime,
      startPlace: startPlace,
      endPlace: endPlace,
      distanceKm: distanceKm,
      companionTags: companionTags,
      purposeTag: purposeTag,
      moodTag: moodTag,
      moodDetail: moodDetail,
      memo: memo,
      photoPaths: photoPaths,
      songTitle: songTitle,
      placesNote: placesNote,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// 예: "서울 → 강릉", 출발지만 있으면 출발지만.
  String get routeSummary {
    if ((startPlace == null || startPlace!.isEmpty) &&
        (endPlace == null || endPlace!.isEmpty)) {
      return '';
    }
    if (startPlace == null || startPlace!.isEmpty) return endPlace!;
    if (endPlace == null || endPlace!.isEmpty) return startPlace!;
    return '$startPlace → $endPlace';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'start_place': startPlace,
      'end_place': endPlace,
      'distance_km': distanceKm,
      'companion_tags': jsonEncode(companionTags),
      'purpose_tag': purposeTag.dbValue,
      'mood_tag': moodTag.dbValue,
      'mood_detail': moodDetail,
      'memo': memo,
      'photo_paths': jsonEncode(photoPaths),
      'song_title': songTitle,
      'places_note': placesNote,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Drive.fromMap(Map<String, dynamic> map) {
    return Drive(
      id: map['id'] as int?,
      date: map['date'] as String,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      startPlace: map['start_place'] as String?,
      endPlace: map['end_place'] as String?,
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      companionTags:
          (jsonDecode(map['companion_tags'] as String) as List<dynamic>)
              .cast<String>(),
      purposeTag: PurposeTag.fromDbValue(map['purpose_tag'] as String),
      moodTag: EmotionCategory.fromDbValue(map['mood_tag'] as String),
      moodDetail: map['mood_detail'] as String?,
      memo: map['memo'] as String?,
      photoPaths:
          (jsonDecode(map['photo_paths'] as String) as List<dynamic>)
              .cast<String>(),
      songTitle: map['song_title'] as String?,
      placesNote: map['places_note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
