import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 개인정보처리방침(GitHub Pages) URL.
const String kPrivacyPolicyUrl =
    'https://a01065365623-lab.github.io/CarDaily/privacy-policy.html';

/// 설정 화면 "다른 앱" 섹션에 노출할 K-Brain Games Lab 앱 한 개.
class CrossPromoApp {
  const CrossPromoApp({
    required this.packageName,
    required this.name,
    required this.description,
  });

  /// Google Play applicationId (각 프로젝트 android/app/build.gradle*에서 확인).
  final String packageName;

  /// 앱 이름(번역하지 않음). ARB에도 동일 값으로 들어 있다.
  final String Function(AppLocalizations l10n) name;

  /// 한 줄 설명(14개 언어 ARB).
  final String Function(AppLocalizations l10n) description;

  Uri get playStoreUri =>
      Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
}

/// Google Play에 게시된 앱만 넣는다.
///
/// 새 앱이 게시되면 ARB에 `otherAppXxxName`/`otherAppXxxDesc` 키를 추가하고
/// 아래 목록에 한 줄을 추가하면 된다.
final List<CrossPromoApp> kCrossPromoApps = [
  CrossPromoApp(packageName: 'com.kbraingames.drinkdiary', name: (l) => l.otherAppDrinkDiaryName, description: (l) => l.otherAppDrinkDiaryDesc),
  CrossPromoApp(packageName: 'com.kbraingames.calsnap', name: (l) => l.otherAppCalSnapName, description: (l) => l.otherAppCalSnapDesc),
  CrossPromoApp(packageName: 'com.wedi.app', name: (l) => l.otherAppWediName, description: (l) => l.otherAppWediDesc),
  CrossPromoApp(packageName: 'com.wordbattle.app', name: (l) => l.otherAppWordBattleName, description: (l) => l.otherAppWordBattleDesc),
  CrossPromoApp(packageName: 'com.kbraingames.lexdart', name: (l) => l.otherAppLexDartName, description: (l) => l.otherAppLexDartDesc),
  CrossPromoApp(packageName: 'com.kbraingames.lextile', name: (l) => l.otherAppLexTileName, description: (l) => l.otherAppLexTileDesc),
  CrossPromoApp(packageName: 'com.lexfall.app', name: (l) => l.otherAppLexfallName, description: (l) => l.otherAppLexfallDesc),
  CrossPromoApp(packageName: 'com.wordbreakerquest.app', name: (l) => l.otherAppWordBreakerQuestName, description: (l) => l.otherAppWordBreakerQuestDesc),
];
