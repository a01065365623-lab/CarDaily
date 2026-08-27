/// 테스트/실 광고 ID 전환 스위치.
///
/// true  → Google 공식 테스트 광고 ID 사용 (개발/QA 중, 항상 로드되고 실제 수익은 발생하지 않음)
/// false → 실제 배포용 광고 ID 사용
///
/// 배포(스토어 업로드) 전 반드시 false로 바꾸고, 아래 `_bannerRealAdUnitId`/
/// `_interstitialRealAdUnitId`를 AdMob 콘솔(https://admob.google.com)에서 발급받은
/// 실제 광고 단위 ID로 교체할 것. 앱 ID는
/// android/app/src/main/AndroidManifest.xml의 com.google.android.gms.ads.APPLICATION_ID
/// 메타데이터에도 등록돼 있으므로 함께 바꿔야 한다.
const bool kUseTestAdUnitIds = true;

/// AdMob 광고 단위 ID 설정.
class AdConstants {
  AdConstants._();

  // ── 배너 광고 단위 ID ──
  static const String _bannerTestAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Google 테스트 배너 ID
  // TODO: 실제 배너 광고 단위 ID로 교체
  static const String _bannerRealAdUnitId = 'ca-app-pub-REPLACE_ME/REPLACE_ME';

  static String get bannerAdUnitId => kUseTestAdUnitIds ? _bannerTestAdUnitId : _bannerRealAdUnitId;

  // ── 전면 광고 단위 ID ──
  static const String _interstitialTestAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Google 테스트 전면 ID
  // TODO: 실제 전면 광고 단위 ID로 교체
  static const String _interstitialRealAdUnitId = 'ca-app-pub-REPLACE_ME/REPLACE_ME';

  static String get interstitialAdUnitId => kUseTestAdUnitIds ? _interstitialTestAdUnitId : _interstitialRealAdUnitId;
}
