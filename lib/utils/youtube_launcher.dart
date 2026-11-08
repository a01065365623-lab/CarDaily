import 'package:url_launcher/url_launcher.dart';

/// [query]로 유튜브 검색 결과 페이지를 유튜브 앱(또는 브라우저)으로 연다.
Future<void> openYoutubeSearch(String query) async {
  final uri = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(query)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
