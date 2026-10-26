import '../models/schedule_preferences.dart';

class PreferencesService {
  static String _profile = 'demo-cs-2024';
  static final _profiles = <String, SchedulePreferences>{};
  static void useProfile(String id) => _profile = id;

  static void savePreferences(SchedulePreferences preferences) {
    _profiles[_profile] = preferences;
  }

  static SchedulePreferences? get preferences {
    return _profiles[_profile];
  }

  static bool get hasPreferences {
    return _profiles[_profile] != null;
  }
}
