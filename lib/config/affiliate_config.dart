/// 지역/언어별 쇼핑 제휴 링크 설정.
///
/// CalSnap/wedi_app에서 검증된 3사(쿠팡파트너스/네이버/아마존 어소시에이트) 딥링크
/// 패턴을 그대로 이식했다. 실제 서비스 배포 전 아래 값을 전부 CarDaily 전용
/// 계정의 실제 제휴 ID로 교체해야 한다(다른 앱 것을 그대로 쓰면 수익이 그 계정으로
/// 잡히거나, 심하면 각 플랫폼 제휴 정책 위반이 될 수 있다).
class AffiliateConfig {
  AffiliateConfig._();

  /// 쿠팡파트너스 채널 ID. 현재는 검색 결과 URL(coupang.com/np/search)만 쓰고
  /// 있어 필수는 아니지만, 추후 파트너스 API로 정식 딥링크를 발급받을 경우 필요하다.
  /// TODO: 실제 쿠팡파트너스 채널 ID로 교체
  static const String coupangChannelId = 'YOUR_COUPANG_CHANNEL_ID';

  /// 아마존 어소시에이트 추적 태그(스토어 ID).
  static const String amazonAssociateTag = 'wedia';
}
