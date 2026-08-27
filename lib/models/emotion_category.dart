import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 오늘 운행의 기분(1차 카테고리). 필수 선택.
///
/// [label]은 DB 저장/조회에 쓰이는 안정적인 한국어 키다. 이미 저장된 과거 기록과의
/// 호환을 위해 앱 언어가 바뀌어도 이 값 자체는 바뀌지 않는다. 화면에 보여줄 때는
/// 반드시 [localizedLabel]을 사용해 현재 언어로 번역된 문구를 표시한다.
enum EmotionCategory {
  joy('즐거움', '😄'),
  celebration('축하', '🎉'),
  comfort('위로', '🤗'),
  calm('평온', '😌'),
  loneliness('외로움', '🥲'),
  stress('스트레스', '😣'),
  boredom('지루함', '🥱'),
  none('그냥', '🤷');

  const EmotionCategory(this.label, this.emoji);

  final String label;
  final String emoji;

  String get dbValue => label;

  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case EmotionCategory.joy:
        return l10n.emotionCategoryJoy;
      case EmotionCategory.celebration:
        return l10n.emotionCategoryCelebration;
      case EmotionCategory.comfort:
        return l10n.emotionCategoryComfort;
      case EmotionCategory.calm:
        return l10n.emotionCategoryCalm;
      case EmotionCategory.loneliness:
        return l10n.emotionCategoryLoneliness;
      case EmotionCategory.stress:
        return l10n.emotionCategoryStress;
      case EmotionCategory.boredom:
        return l10n.emotionCategoryBoredom;
      case EmotionCategory.none:
        return l10n.emotionCategoryNone;
    }
  }

  static EmotionCategory fromDbValue(String value) {
    return EmotionCategory.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => EmotionCategory.none,
    );
  }
}
