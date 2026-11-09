import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_constants.dart';

/// 배너 광고. 로딩 중이거나 로드에 실패하면 크기가 0인 위젯을 보여줘서, 광고
/// 실패가 레이아웃이나 앱 흐름에 영향을 주지 않게 한다.
///
/// - [adaptive]가 false면 표준 배너(320x50), true면 화면 폭에 맞춘 적응형 앵커
///   배너를 쓴다.
/// - [padding]은 광고가 실제로 로드됐을 때만 적용된다. 버튼과의 간격을 여기로
///   주면 광고가 없을 때 빈 여백이 남지 않는다.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    this.adaptive = false,
    this.padding = EdgeInsets.zero,
  });

  final bool adaptive;
  final EdgeInsetsGeometry padding;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loadStarted = false;
  bool _disposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 적응형 크기는 화면 폭(MediaQuery)이 필요해서 initState 대신 여기서 한 번만 시작한다.
    if (_loadStarted) return;
    _loadStarted = true;
    _loadBanner(MediaQuery.sizeOf(context).width.truncate());
  }

  Future<void> _loadBanner(int width) async {
    AdSize size = AdSize.banner;
    if (widget.adaptive) {
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (_disposed) return;
      if (adaptiveSize != null) size = adaptiveSize;
    }
    final ad = BannerAd(
      size: size,
      adUnitId: AdConstants.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // 로드가 끝나기 전에 화면을 나갔으면 받은 광고를 바로 정리한다(누수 방지).
          if (_disposed) {
            ad.dispose();
            return;
          }
          setState(() => _bannerAd = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
