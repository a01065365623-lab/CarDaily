import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 인트로(스플래시) 화면에 랜덤으로 노출되는 드라이브 감성 문구 목록.
///
/// [HomeCalendarScreen]으로 진입하기 직전, 매번 이 중 하나를 무작위로 골라 보여준다.
/// 문구 자체는 [AppLocalizations]의 ARB 리소스(introMessage1~12)에서 가져오므로
/// 앱 언어에 따라 자동으로 번역된 문구가 노출된다.
List<String> introMessages(AppLocalizations l10n) => [
      l10n.introMessage1,
      l10n.introMessage2,
      l10n.introMessage3,
      l10n.introMessage4,
      l10n.introMessage5,
      l10n.introMessage6,
      l10n.introMessage7,
      l10n.introMessage8,
      l10n.introMessage9,
      l10n.introMessage10,
      l10n.introMessage11,
      l10n.introMessage12,
    ];
