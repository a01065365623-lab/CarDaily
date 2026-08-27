import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash_intro_screen.dart';
import 'services/ad_service.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 첫 프레임을 늦추지 않도록 AdMob 초기화는 백그라운드에서 진행한다. 실패해도
  // AdService 내부에서 조용히 무시하므로 앱 실행에 영향 없음.
  unawaited(AdService.instance.initialize());
  // 지원하는 14개 언어 모두의 날짜 심볼(요일/월 이름 등)을 미리 로드해 둔다.
  // TableCalendar나 DateFormat.MMMd가 현재 앱 언어로 즉시 포맷할 수 있어야 하기 때문.
  for (final locale in AppLocalizations.supportedLocales) {
    await initializeDateFormatting(locale.toString());
  }
  runApp(const CarDailyApp());
}

class CarDailyApp extends StatelessWidget {
  const CarDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarDaily',
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // 기기 locale이 14개 지원 언어 중 하나와 일치하면 그 언어를, 없으면 앱의 기본
      // 언어인 한국어로 폴백한다. (localeResolutionCallback을 지정하지 않으면 Flutter는
      // 매칭 실패 시 supportedLocales의 "첫 번째" 항목으로 조용히 폴백하는데, 이 목록은
      // gen-l10n이 알파벳순으로 생성하므로 실제로는 'ar'로 떨어지는 등 의도와 무관한
      // 동작이 될 수 있다. 그래서 한국어를 명시적인 기본값으로 지정한다.)
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == locale.languageCode) return supported;
          }
        }
        return const Locale('ko');
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.amber,
          primary: AppColors.amber,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const SplashIntroScreen(),
    );
  }
}
