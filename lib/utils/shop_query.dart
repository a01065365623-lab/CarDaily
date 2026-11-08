import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../db/database_helper.dart';
import 'date_formatter.dart';

/// 좌측 하단 쇼핑 미니 FAB(캘린더/일자 상세 화면 공용)가 어떤 검색어로 쇼핑
/// 링크를 열지 정한다. 그 날짜에 기록된 운행이 있으면 첫 운행의 목적에 맞는
/// 검색어로, 없으면 "차량용품" 일반 검색어로 연다.
Future<String> resolveShopQueryForDate(
  BuildContext context,
  DateTime date,
) async {
  final drives = await DatabaseHelper.instance.getDrivesForDate(dateKey(date));
  if (drives.isNotEmpty) {
    if (!context.mounted) return '';
    return drives.first.purposeTag.shopQuery(context);
  }
  if (!context.mounted) return '';
  return AppLocalizations.of(context)!.shopQueryEtc;
}
