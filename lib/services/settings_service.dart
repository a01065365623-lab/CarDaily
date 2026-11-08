import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역 사용자 설정(SharedPreferences 기반)을 다룬다.
class SettingsService {
  SettingsService._();

  static const String _keyVehicleNickname = 'vehicleNickname';

  static Future<String?> getVehicleNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyVehicleNickname);
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> setVehicleNickname(String? nickname) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = nickname?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(_keyVehicleNickname);
    } else {
      await prefs.setString(_keyVehicleNickname, trimmed);
    }
  }
}
