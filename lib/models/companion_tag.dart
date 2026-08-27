import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 함께 운행한 사람.
///
/// [label]은 DB 저장/조회에 쓰이는 안정적인 한국어 키다. 이미 저장된 과거 기록과의
/// 호환을 위해 앱 언어가 바뀌어도 이 값 자체는 바뀌지 않는다. 화면에 보여줄 때는
/// 반드시 [localizedLabel]을 사용해 현재 언어로 번역된 문구를 표시한다.
enum CompanionTag {
  alone('혼자'),
  friend('친구'),
  family('가족'),
  partner('연인'),
  coworker('직장동료');

  const CompanionTag(this.label);

  final String label;

  String get dbValue => label;

  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case CompanionTag.alone:
        return l10n.companionTagAlone;
      case CompanionTag.friend:
        return l10n.companionTagFriend;
      case CompanionTag.family:
        return l10n.companionTagFamily;
      case CompanionTag.partner:
        return l10n.companionTagPartner;
      case CompanionTag.coworker:
        return l10n.companionTagCoworker;
    }
  }

  static CompanionTag fromDbValue(String value) {
    return CompanionTag.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => CompanionTag.alone,
    );
  }

  /// DB에 저장된 [rawValue](칩에서 고른 값 또는 직접 입력한 자유 텍스트)를 화면에 보여줄
  /// 문구로 변환한다. 알려진 칩 라벨이면 현재 언어로 번역해서 보여주고, 사용자가 직접
  /// 입력한 자유 텍스트라면 번역할 수 없으므로 원문 그대로 보여준다.
  static String display(BuildContext context, String rawValue) {
    for (final tag in CompanionTag.values) {
      if (tag.label == rawValue) return tag.localizedLabel(context);
    }
    return rawValue;
  }

  /// 여러 동행자 태그를 쉼표로 이어붙인 표시 문구로 변환한다.
  static String displayList(BuildContext context, List<String> rawValues) {
    if (rawValues.isEmpty) return display(context, CompanionTag.alone.label);
    return rawValues.map((v) => display(context, v)).join(', ');
  }
}
