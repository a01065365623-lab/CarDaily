import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sound_mode_advanced/sound_mode_advanced.dart';

import '../constants/intro_messages.dart';
import '../services/ad_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import 'home_calendar_screen.dart';

/// 앱 진입 시 [HomeCalendarScreen]으로 가기 직전 매번 짧게 보여주는
/// 감성 인트로(스플래시) 화면.
///
/// 일정 시간 자동 노출 후 페이드 전환으로 캘린더 화면으로 넘어가며,
/// 우측 상단의 "건너뛰기" 버튼을 눌러 바로 스킵할 수 있다.
/// (화면 전체를 탭하면 스킵되게 하면 문구를 읽으려던 터치에도 바로
/// 넘어가버리는 문제가 있어, 명시적인 버튼으로만 스킵하도록 한다.)
///
/// 이 화면 직후(=앱을 새로 켤 때마다)가 전면 광고 노출 시점이다. 콜드 스타트
/// 1회차나 빈도 제한에 걸리면 [AdService]가 조용히 건너뛰므로, 아래 코드는
/// "인트로 다음에는 항상 전면 광고 시도 → 그다음 캘린더"라는 순서만 신경 쓴다.
class SplashIntroScreen extends StatefulWidget {
  const SplashIntroScreen({super.key});

  @override
  State<SplashIntroScreen> createState() => _SplashIntroScreenState();
}

class _SplashIntroScreenState extends State<SplashIntroScreen>
    with SingleTickerProviderStateMixin {
  // 배경음악 길이(약 5~7초)에 맞춰 인트로를 7.5초간 노출한다.
  static const Duration _displayDuration = Duration(milliseconds: 7500);
  // 화면 페이드 전환과 배경음악 페이드아웃이 같은 길이로 동시에 진행되어,
  // 음악이 끝나갈 무렵 화면도 함께 자연스럽게 어두워지도록 한다.
  static const Duration _fadeDuration = Duration(milliseconds: 500);

  // 은은하게 들리는 수준. 필요하면 0.15~0.25 사이에서 조정한다.
  static const double _bgmVolume = 0.2;
  static const String _bgmAssetPath = 'sounds/intro_bgm.mp3';

  static const int _messageCount = 12;
  late final int _messageIndex;
  late final AnimationController _fadeController;
  bool _isNavigating = false;

  AudioPlayer? _bgmPlayer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // 실제 문구 문자열은 AppLocalizations가 필요한데, initState에서는 아직
    // InheritedWidget(Localizations)을 안전하게 구독할 수 없으므로 인덱스만
    // 미리 뽑아 두고 실제 문구는 build()에서 현재 언어로 조회한다.
    _messageIndex = Random().nextInt(_messageCount);
    _fadeController = AnimationController(vsync: this, duration: _fadeDuration);
    _navigationTimer = Timer(_displayDuration, _goToHome);
    unawaited(_playIntroMusic());
  }

  /// 설정에서 꺼져있거나 기기가 무음/진동 모드면 재생하지 않는다.
  Future<void> _playIntroMusic() async {
    final musicEnabled = await SettingsService.isIntroMusicEnabled();
    if (!musicEnabled || !mounted) return;
    if (await _isDeviceMutedOrVibrate()) return;
    if (!mounted) return;

    final player = AudioPlayer();
    _bgmPlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(_bgmVolume);
      await player.play(AssetSource(_bgmAssetPath));
    } catch (_) {
      // 오디오 재생 실패는 인트로 화면 자체를 막을 이유가 아니므로 조용히 무시한다.
    }
  }

  Future<bool> _isDeviceMutedOrVibrate() async {
    try {
      final status = await SoundMode.ringerModeStatus;
      return status == RingerModeStatus.silent || status == RingerModeStatus.vibrate;
    } catch (_) {
      // 감지가 지원되지 않는 플랫폼/기기에서는 재생을 막지 않는다.
      return false;
    }
  }

  /// 곡이 인트로 노출 시간보다 길 때 화면 전환 시점에 뚝 끊기지 않도록,
  /// 화면 페이드 전환과 같은 길이(_fadeDuration) 동안 볼륨을 서서히 낮춘 뒤 멈춘다.
  Future<void> _fadeOutAndStopMusic() async {
    final player = _bgmPlayer;
    if (player == null) return;
    _bgmPlayer = null; // dispose()에서 중복으로 stop/dispose하지 않도록 즉시 비움
    const steps = 8;
    final stepDuration = _fadeDuration ~/ steps;
    try {
      for (var i = steps - 1; i >= 0; i--) {
        await player.setVolume(_bgmVolume * i / steps);
        await Future.delayed(stepDuration);
      }
      await player.stop();
    } catch (_) {
      // 화면 전환은 이미 진행 중이므로 정지 실패는 무시한다.
    } finally {
      await player.dispose();
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _fadeController.dispose();
    _bgmPlayer?.dispose();
    super.dispose();
  }

  Future<void> _goToHome() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    unawaited(_fadeOutAndStopMusic());
    // 인트로 화면(첫 화면) 바로 다음, 캘린더로 넘어가기 전에 전면 광고를 시도한다.
    await AdService.instance.maybeShowInterstitialOnColdStart();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: _fadeDuration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeCalendarScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = introMessages(l10n)[_messageIndex];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.woodBrown,
              AppColors.amberDark,
              AppColors.amber,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Expanded(
                    flex: 3,
                    child: Center(child: _IntroIllustration()),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 인트로 상단 일러스트.
///
/// TODO(assets): 실제 감성 일러스트가 준비되면
/// `assets/images/intro_illustration.png`를 pubspec.yaml assets에 등록하고
/// 아래 CustomPaint 플레이스홀더를 `Image.asset('assets/images/intro_illustration.png')`
/// 로 교체할 것.
class _IntroIllustration extends StatelessWidget {
  const _IntroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _MoonAndGlassPainter(),
      ),
    );
  }
}

class _MoonAndGlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 은은한 달빛 후광
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);

    // 달
    final moonCenter = Offset(size.width * 0.62, size.height * 0.32);
    final moonRadius = size.width * 0.16;
    final moonPaint = Paint()..color = AppColors.amberLight;
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);

    // 달의 그림자(초승달 느낌)
    final shadowPaint = Paint()..color = AppColors.amberDark.withValues(alpha: 0.55);
    canvas.drawCircle(
      Offset(moonCenter.dx + moonRadius * 0.5, moonCenter.dy - moonRadius * 0.15),
      moonRadius * 0.9,
      shadowPaint,
    );

    // 별
    _drawStar(canvas, Offset(size.width * 0.22, size.height * 0.22), 3.5);
    _drawStar(canvas, Offset(size.width * 0.32, size.height * 0.42), 2.5);
    _drawStar(canvas, Offset(size.width * 0.14, size.height * 0.5), 2.5);

    // 도로(원근감 있는 사다리꼴)와 중앙선
    final roadPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final roadTopY = size.height * 0.7;
    final roadBottomY = size.height * 0.9;
    final roadPath = Path()
      ..moveTo(size.width * 0.42, roadTopY)
      ..lineTo(size.width * 0.58, roadTopY)
      ..lineTo(size.width * 0.78, roadBottomY)
      ..lineTo(size.width * 0.22, roadBottomY)
      ..close();
    canvas.drawPath(roadPath, roadPaint);

    final dashPaint = Paint()
      ..color = AppColors.amberDark.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t0 = 0.08 + i * 0.28;
      final t1 = t0 + 0.14;
      canvas.drawLine(
        Offset(size.width * 0.5, roadTopY + (roadBottomY - roadTopY) * t0),
        Offset(size.width * 0.5, roadTopY + (roadBottomY - roadTopY) * t1),
        dashPaint,
      );
    }

    // 차 (둥근 실루엣 + 바퀴)
    final carPaint = Paint()..color = AppColors.terracotta.withValues(alpha: 0.9);
    final carBodyRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, roadBottomY - 20),
      width: size.width * 0.34,
      height: size.height * 0.1,
    );
    final carBody = RRect.fromRectAndRadius(carBodyRect, const Radius.circular(10));
    canvas.drawRRect(carBody, carPaint);

    final cabinRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, carBodyRect.top + 2),
      width: size.width * 0.2,
      height: size.height * 0.06,
    );
    final cabin = RRect.fromRectAndCorners(
      cabinRect,
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
    );
    canvas.drawRRect(cabin, carPaint);

    final wheelPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final wheelY = carBodyRect.bottom;
    canvas.drawCircle(Offset(carBodyRect.left + 14, wheelY), 6, wheelPaint);
    canvas.drawCircle(Offset(carBodyRect.right - 14, wheelY), 6, wheelPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(center, size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
