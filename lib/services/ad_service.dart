import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/ad_constants.dart';

/// AdMob 초기화 + 전면 광고 노출 빈도 제한.
///
/// 전면 광고는 인트로(스플래시) 화면 직후, 즉 앱을 새로 켤 때마다(콜드 스타트)
/// [maybeShowInterstitialOnColdStart]로 노출한다. 규칙:
/// - 이 기기에서의 첫 실행(콜드 스타트 1회차)에는 노출하지 않는다.
/// - 그 이후 콜드 스타트부터는 마지막 노출로부터 [_minInterval] 이상 지났을 때만
///   노출한다(매번 뜨면 앱 시작이 너무 번거로워지므로).
/// - 광고 로드/노출에 실패해도 예외를 던지지 않고 조용히 넘어간다 — 광고는 부가
///   기능일 뿐, 앱 진입이라는 핵심 흐름을 막아서는 안 되기 때문이다.
///
/// [initialize]는 main()에서 앱 시작과 동시에(인트로 화면이 뜨기도 전에) 호출돼
/// 광고 로드를 미리 시작해 둔다. 인트로 화면이 [_displayDuration]만큼 노출되는
/// 동안 그 로드가 백그라운드에서 끝날 시간을 벌어 주는 셈이라, 인트로 직후
/// [maybeShowInterstitialOnColdStart]가 호출될 때 이미 광고가 준비돼 있는 경우가
/// 많다. 아직 로드 중이라면 [_loadTimeout]까지만 기다린다.
class AdService {
  AdService._internal();
  static final AdService instance = AdService._internal();

  static const _keyLastShownAt = 'interstitial_last_shown_at_millis';
  static const _keyColdStartCount = 'ad_cold_start_count';
  static const Duration _minInterval = Duration(minutes: 3);
  static const Duration _loadTimeout = Duration(seconds: 8);

  InterstitialAd? _interstitialAd;
  bool _initialized = false;
  Completer<InterstitialAd?>? _pendingLoad;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _startLoadingInterstitial();
    } catch (_) {
      // 초기화 실패해도(예: 네트워크 없음) 앱 실행 자체를 막지 않는다.
    }
  }

  /// 이미 로드됐거나 로드 중이면 그대로 두고, 아니라면 새 로드를 시작한다.
  /// 항상 "지금 진행 중인(또는 방금 끝난) 로드"를 나타내는 completer를 반환한다.
  Completer<InterstitialAd?> _startLoadingInterstitial() {
    final existing = _pendingLoad;
    if (existing != null) return existing;

    final completer = Completer<InterstitialAd?>();
    _pendingLoad = completer;
    try {
      InterstitialAd.load(
        adUnitId: AdConstants.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _pendingLoad = null;
            if (!completer.isCompleted) completer.complete(ad);
          },
          onAdFailedToLoad: (_) {
            _interstitialAd = null;
            _pendingLoad = null;
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (_) {
      _pendingLoad = null;
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer;
  }

  /// 이미 로드된 광고가 있으면 즉시 반환하고, 없으면 로드를 시작하거나 진행 중인
  /// 로드에 [_loadTimeout]까지만 합류해서 기다린다.
  Future<InterstitialAd?> _awaitInterstitial() async {
    final ready = _interstitialAd;
    if (ready != null) return ready;
    final pending = _startLoadingInterstitial();
    try {
      return await pending.future.timeout(_loadTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  /// 인트로 화면 직후(=콜드 스타트마다) 호출한다. 빈도 제한을 통과하면 전면
  /// 광고를 보여주고, 광고가 닫히거나 실패한 뒤에 반환한다. 어느 경우든 이
  /// Future가 끝나면 곧바로 다음 화면(캘린더)으로 넘어가면 된다.
  Future<void> maybeShowInterstitialOnColdStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final coldStartCount = (prefs.getInt(_keyColdStartCount) ?? 0) + 1;
      await prefs.setInt(_keyColdStartCount, coldStartCount);

      // 이 기기에서 앱을 처음 켰을 때는 노출하지 않는다.
      if (coldStartCount <= 1) return;

      final lastShownMillis = prefs.getInt(_keyLastShownAt);
      if (lastShownMillis != null) {
        final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastShownMillis));
        if (elapsed < _minInterval) return;
      }

      // main()에서 이미 초기화를 시작해 뒀겠지만, 혹시 아직이라면 여기서 보장한다.
      await initialize();
      final ad = await _awaitInterstitial();
      if (ad == null) return;
      _interstitialAd = null;

      final shown = Completer<void>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          if (!shown.isCompleted) shown.complete();
        },
        onAdFailedToShowFullScreenContent: (a, error) {
          a.dispose();
          if (!shown.isCompleted) shown.complete();
        },
      );
      await ad.show();
      await prefs.setInt(_keyLastShownAt, DateTime.now().millisecondsSinceEpoch);
      await shown.future;
      _startLoadingInterstitial(); // 다음 노출을 위해 미리 재로드
    } catch (_) {
      // 광고 실패는 앱 진입 흐름과 무관하게 조용히 무시한다.
    }
  }
}
