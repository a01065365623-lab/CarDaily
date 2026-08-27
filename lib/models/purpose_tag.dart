import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 오늘 운행의 목적.
///
/// [label]은 DB 저장/조회에 쓰이는 안정적인 한국어 키다. 이미 저장된 과거 기록과의
/// 호환을 위해 앱 언어가 바뀌어도 이 값 자체는 바뀌지 않는다. 화면에 보여줄 때는
/// 반드시 [localizedLabel]을 사용해 현재 언어로 번역된 문구를 표시한다.
enum PurposeTag {
  trip('여행'),
  date('데이트'),
  commute('출퇴근'),
  drive('드라이브'),
  etc('기타');

  const PurposeTag(this.label);

  final String label;

  String get dbValue => label;

  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case PurposeTag.trip:
        return l10n.purposeTagTrip;
      case PurposeTag.date:
        return l10n.purposeTagDate;
      case PurposeTag.commute:
        return l10n.purposeTagCommute;
      case PurposeTag.drive:
        return l10n.purposeTagDrive;
      case PurposeTag.etc:
        return l10n.purposeTagEtc;
    }
  }

  /// 저장 완료 스낵바에서 "관련 상품 보기"를 눌렀을 때 쓰는 쇼핑 검색어.
  String shopQuery(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case PurposeTag.trip:
        return l10n.shopQueryTrip;
      case PurposeTag.date:
        return l10n.shopQueryDate;
      case PurposeTag.commute:
        return l10n.shopQueryCommute;
      case PurposeTag.drive:
        return l10n.shopQueryDrive;
      case PurposeTag.etc:
        return l10n.shopQueryEtc;
    }
  }

  static PurposeTag fromDbValue(String value) {
    return PurposeTag.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => PurposeTag.drive,
    );
  }
}
