import 'package:shared_preferences/shared_preferences.dart';

import '../models/media.dart';

class SettingsStore {
  static const _lang = 'nazzil.language';
  static const _theme = 'nazzil.theme';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      language: prefs.getString(_lang) ?? 'system',
      theme: prefs.getString(_theme) ?? 'system',
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lang, settings.language);
    await prefs.setString(_theme, settings.theme);
  }
}
