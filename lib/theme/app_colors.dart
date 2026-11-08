import 'package:flutter/material.dart';

/// 우드·앰버 톤의 따뜻한 컬러 팔레트. 차량을 "관리"하는 앱이 아니라 그날의 이야기를
/// 남기는 다이어리라는 컨셉에 맞춰, 차갑고 임상적인 톤 대신 나무결/호박색 계열을 쓴다.
class AppColors {
  AppColors._();

  // 메인 브랜드 컬러: 앰버(호박색)
  static const Color amber = Color(0xFFC97B34);
  static const Color amberLight = Color(0xFFF3E1C8);
  static const Color amberDark = Color(0xFF8A5A26);

  // 우드(나무결) 톤: 배경/카드
  static const Color woodBrown = Color(0xFF6B4A34);
  static const Color woodBrownLight = Color(0xFFF6EEE4);

  // 배경
  static const Color background = Color(0xFFFDF8F2);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // 텍스트
  static const Color textPrimary = Color(0xFF3B2E24);
  static const Color textSecondary = Color(0xFF8A7A6A);

  // 포인트: 감정 태그용 테라코타
  static const Color terracotta = Color(0xFFC1603E);
  static const Color terracottaBg = Color(0xFFF6E2D8);

  // 포인트: 동행 태그용 세이지 그린 (앰버와 대비되면서도 톤 다운된 색)
  static const Color sage = Color(0xFF7C8B6F);
  static const Color sageBg = Color(0xFFE6EBDF);

  // 포인트: 목적 태그용 스틸 블루 (도로/이정표 느낌)
  static const Color route = Color(0xFF4E7A96);
  static const Color routeBg = Color(0xFFE2ECF0);

  // 캘린더 기록 점(dot)
  static const Color calendarDot = amber;

  // 포인트: "기름 먹은 날" 버튼용 골드(노랑-주황). 메인 앰버와 구분되도록 더 밝고 노란 톤.
  static const Color fuelGold = Color(0xFFD9A441);

  static const Color divider = Color(0xFFE7DDCF);
}
