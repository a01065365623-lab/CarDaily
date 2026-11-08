import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 병원(정비) 예약의 유형.
///
/// [label]은 DB 저장/조회에 쓰이는 안정적인 한국어 키다. 이미 저장된 과거 기록과의
/// 호환을 위해 앱 언어가 바뀌어도 이 값 자체는 바뀌지 않는다. 화면에 보여줄 때는
/// 반드시 [localizedLabel]을 사용해 현재 언어로 번역된 문구를 표시한다.
enum PlanType {
  maintenance('정비'),
  carWash('세차'),
  inspection('검사'),
  etc('기타');

  const PlanType(this.label);

  final String label;

  String get dbValue => label;

  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case PlanType.maintenance:
        return l10n.planTypeMaintenance;
      case PlanType.carWash:
        return l10n.planTypeCarWash;
      case PlanType.inspection:
        return l10n.planTypeInspection;
      case PlanType.etc:
        return l10n.planTypeEtc;
    }
  }

  static PlanType fromDbValue(String value) {
    return PlanType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => PlanType.etc,
    );
  }
}
