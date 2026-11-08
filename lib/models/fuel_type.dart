import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// "기름 먹은 날" 기록의 연료 종류.
///
/// [label]은 DB 저장/조회에 쓰이는 안정적인 한국어 키다. 이미 저장된 과거 기록과의
/// 호환을 위해 앱 언어가 바뀌어도 이 값 자체는 바뀌지 않는다. 화면에 보여줄 때는
/// 반드시 [localizedLabel]을 사용해 현재 언어로 번역된 문구를 표시한다.
enum FuelType {
  gasoline('기름'),
  electric('전기'),
  gas('가스'),
  hydrogen('수소'),
  etc('기타');

  const FuelType(this.label);

  final String label;

  String get dbValue => label;

  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case FuelType.gasoline:
        return l10n.fuelTypeGasoline;
      case FuelType.electric:
        return l10n.fuelTypeElectric;
      case FuelType.gas:
        return l10n.fuelTypeGas;
      case FuelType.hydrogen:
        return l10n.fuelTypeHydrogen;
      case FuelType.etc:
        return l10n.fuelTypeEtc;
    }
  }

  /// 이 연료 종류에 맞는 충전/주유량 단위. '기타'는 단위 없이 숫자만 입력받는다.
  String? unitLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case FuelType.gasoline:
      case FuelType.gas:
        return l10n.fuelUnitLiter;
      case FuelType.electric:
        return l10n.fuelUnitKwh;
      case FuelType.hydrogen:
        return l10n.fuelUnitKg;
      case FuelType.etc:
        return null;
    }
  }

  static FuelType fromDbValue(String value) {
    return FuelType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => FuelType.etc,
    );
  }
}
