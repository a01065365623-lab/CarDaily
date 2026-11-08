import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/affiliate_service.dart';

/// CalSnap/wedi_app의 _ShopBtn / confirmLink 패턴 이식.
/// 실제 이동 URL을 텍스트로 보여주는 확인 바텀시트를 반드시 거친 뒤에만 이동한다
/// (쿠팡파트너스는 이 흐름이 없으면 심사 반려된 이력이 있고, 네이버·아마존까지
/// 모두 동일한 흐름으로 통일했다).
Future<void> confirmAndLaunchAffiliateLink(
  BuildContext context,
  AffiliateLink link,
) async {
  if (!link.requiresConfirm) {
    await _launch(context, link.url);
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    builder:
        (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shopLinkConfirmTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(link.url, style: const TextStyle(color: Colors.blueGrey)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.commonCancelButton),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.shopLinkGoButton),
                  ),
                ],
              ),
            ],
          ),
        ),
  );
  if (confirmed != true || !context.mounted) return;
  await _launch(context, link.url);
}

Future<void> _launch(BuildContext context, String url) async {
  try {
    await AffiliateService.instance.launch(url);
  } catch (_) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.shopLinkOpenFailed)));
    }
  }
}

/// 저장 완료 알림 스낵바가 자동으로 사라지기까지의 시간. 짧게 자동으로 닫히고,
/// 급하면 X 버튼으로도 바로 닫을 수 있다.
const Duration _recordSavedSnackbarDuration = Duration(seconds: 5);

/// 저장 완료 알림 스낵바. 홈 캘린더/일자 상세 화면 양쪽에서 기록 저장 직후 공용으로
/// 쓴다. "관련 상품 보기" 액션은 좌측 하단 쇼핑 미니 FAB로 옮겨갔다
/// (home_calendar_screen.dart/daily_detail_screen.dart의 shop FAB 참고).
///
/// 좌우 폭은 그대로 두고, 위아래 여백만 2/3로 줄여 세로 크기를 줄인다.
/// 텍스트 크기는 가독성을 위해 그대로 둔다.
void showRecordSavedSnackbar(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      duration: _recordSavedSnackbarDuration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14 * 2 / 3),
      content: Row(
        children: [
          Expanded(
            child: Text(
              l10n.recordInputSavedSnackbarMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colors.white,
            tooltip: MaterialLocalizations.of(context).closeButtonLabel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ],
      ),
    ),
  );
}

String _platformLabel(AppLocalizations l10n, AffiliatePlatform platform) {
  switch (platform) {
    case AffiliatePlatform.coupang:
      return l10n.shopPlatformCoupang;
    case AffiliatePlatform.naver:
      return l10n.shopPlatformNaver;
    case AffiliatePlatform.amazon:
      return l10n.shopPlatformAmazon;
  }
}

IconData _platformIcon(AffiliatePlatform platform) {
  switch (platform) {
    case AffiliatePlatform.coupang:
      return Icons.local_shipping_outlined;
    case AffiliatePlatform.naver:
      return Icons.storefront_outlined;
    case AffiliatePlatform.amazon:
      return Icons.shopping_cart_outlined;
  }
}

/// [query]로 쇼핑 제휴 검색 링크를 찾아 연다. 기기 locale에 따라:
/// - 한국어면 쿠팡/네이버 중 고르는 바텀시트를 먼저 보여준다.
/// - 그 외 언어면 후보가 아마존 하나뿐이라 고르는 단계 없이 바로 확인 흐름으로 넘어간다.
/// 두 경우 모두 실제 이동 URL을 보여주는 확인 바텀시트([confirmAndLaunchAffiliateLink])를
/// 거친 뒤에만 실제로 이동한다. 운행 목적 태그를 탭했을 때, 저장 완료 스낵바의
/// 액션 버튼을 눌렀을 때 등 여러 진입점에서 공용으로 쓴다.
Future<void> openShoppingSearch(BuildContext context, String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return;

  final languageCode = Localizations.localeOf(context).languageCode;
  final links = AffiliateService.instance.shoppingLinksFor(
    query: trimmed,
    languageCode: languageCode,
  );
  if (links.isEmpty) return;

  if (links.length == 1) {
    await confirmAndLaunchAffiliateLink(context, links.first);
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  final selected = await showModalBottomSheet<AffiliateLink>(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.shopPickPlatformTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              for (final link in links)
                ListTile(
                  leading: Icon(_platformIcon(link.platform)),
                  title: Text(_platformLabel(l10n, link.platform)),
                  onTap: () => Navigator.pop(ctx, link),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
  );
  if (selected == null || !context.mounted) return;
  await confirmAndLaunchAffiliateLink(context, selected);
}
