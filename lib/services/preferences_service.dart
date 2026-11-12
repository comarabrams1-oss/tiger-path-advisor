import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_preferences.dart';

class PreferencesService {
  static String _profile = 'demo-cs-2024';
  static final _profiles = <String, SchedulePreferences>{};
  static String get profileId => _profile;
  static void useProfile(String id) => _profile = id;

  static String _key(String profile) => 'schedule_preferences_v1_$profile';

  static Future<bool> savePreferences(SchedulePreferences preferences) async {
    final profile = _profile;
    _profiles[profile] = preferences;
    try {
      final storage = await SharedPreferences.getInstance();
      if (!identical(_profiles[profile], preferences)) return true;
      return await storage.setString(
        _key(profile),
        jsonEncode(preferences.toJson()),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> restore() async {
    final profile = _profile;
    if (_profiles.containsKey(profile)) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(profile),
      );
      if (raw != null) {
        _profiles.putIfAbsent(
          profile,
          () => SchedulePreferences.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ),
        );
      }
    } catch (_) {
      // The saved draft or defaults can supply preferences if storage fails.
    }
  }

  static SchedulePreferences? get preferences {
    return _profiles[_profile];
  }

  static bool get hasPreferences {
    return _profiles[_profile] != null;
  }
}
