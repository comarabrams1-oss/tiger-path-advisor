import '../models/schedule_preferences.dart';

class PreferencesService {
  static SchedulePreferences? _preferences;

  static void savePreferences(
    SchedulePreferences preferences,
  ) {
    _preferences = preferences;
  }

  static SchedulePreferences? get preferences {
    return _preferences;
  }

  static bool get hasPreferences {
    return _preferences != null;
  }
}