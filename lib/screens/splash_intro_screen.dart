import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

import '../services/ad_service.dart';
import '../theme/app_colors.dart';
import 'home_calendar_screen.dart';

/// 앱 진입 시 [HomeCalendarScreen]으로 가기 직전 매번 짧게 보여주는 인트로 영상 화면.
///
/// 영상이 끝나거나, 재생 1초 후 페이드인하는 우측 상단의 "건너뛰기" 버튼을 누르면
/// 캘린더 화면으로 넘어간다. 영상 로드에 실패하면 단색 배경 폴백 화면으로 대체된다.
///
/// 이 화면 직후(=앱을 새로 켤 때마다)가 전면 광고 노출 시점이다. 콜드 스타트
/// 1회차나 빈도 제한에 걸리면 [AdService]가 조용히 건너뛰므로, 아래 코드는
/// "인트로 다음에는 항상 전면 광고 시도 → 그다음 캘린더"라는 순서만 신경 쓴다.
class SplashIntroScreen extends StatefulWidget {
  const SplashIntroScreen({super.key});

  @override
  State<SplashIntroScreen> createState() => _SplashIntroScreenState();
}

class _SplashIntroScreenState extends State<SplashIntroScreen> {
  static const String _videoAssetPath = 'assets/videos/intro_drive.mp4';

  // 화면이 뜨자마자 버튼부터 눈에 들어오면 산만하니, 잠깐 영상에 시선이 머문 뒤
  // 자연스럽게 나타나도록 살짝 늦춰 페이드인한다.
  static const Duration _skipButtonDelay = Duration(seconds: 1);
  static const Duration _skipButtonFadeDuration = Duration(milliseconds: 400);

  VideoPlayerController? _videoController;
  bool _videoFailed = false;
  bool _showSkipButton = false;
  bool _isNavigating = false;

  Timer? _skipButtonTimer;

  @override
  void initState() {
    super.initState();
    _skipButtonTimer = Timer(_skipButtonDelay, () {
      if (!mounted) return;
      setState(() => _showSkipButton = true);
    });
    unawaited(_initVideo());
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(_videoAssetPath);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onVideoProgress);
      await controller.play();
      setState(() => _videoController = controller);
    } catch (e, stack) {
      debugPrint('[SplashIntroScreen] intro video init failed: $e\n$stack');
      await controller.dispose();
      if (!mounted) return;
      setState(() => _videoFailed = true);
    }
  }

  /// 영상 재생이 끝에 도달하면(반복 재생하지 않으므로) 자동으로 다음 화면으로 넘어간다.
  void _onVideoProgress() {
    final value = _videoController?.value;
    if (value == null || !value.isInitialized) return;
    if (value.duration > Duration.zero && value.position >= value.duration) {
      _goToHome();
    }
  }

  @override
  void dispose() {
    _skipButtonTimer?.cancel();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _goToHome() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    // 인트로 화면(첫 화면) 바로 다음, 캘린더로 넘어가기 전에 전면 광고를 시도한다.
    await AdService.instance.maybeShowInterstitialOnColdStart();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeCalendarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _videoController;
    final videoReady = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.woodBrown,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (videoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else if (_videoFailed)
            _FallbackBackground(appName: l10n.appTitle),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IgnorePointer(
                  ignoring: !_showSkipButton,
                  child: AnimatedOpacity(
                    opacity: _showSkipButton ? 1.0 : 0.0,
                    duration: _skipButtonFadeDuration,
                    child: TextButton(
                      onPressed: _goToHome,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.18),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.splashIntroSkipButton,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 영상 로드/재생에 실패했을 때 보여주는 단색 배경 폴백 화면.
class _FallbackBackground extends StatelessWidget {
  final String appName;

  const _FallbackBackground({required this.appName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.woodBrown,
      alignment: Alignment.center,
      child: Text(
        appName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
