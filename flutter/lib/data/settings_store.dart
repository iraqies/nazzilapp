import 'package:shared_preferences/shared_preferences.dart';

import '../models/media.dart';

class SettingsStore {
  static const _lang = 'nazzil.language';
  static const _palette = 'nazzil.palette';

  /// The theme key of the design before Cinema, where "system" was the default.
  static const _oldTheme = 'nazzil.theme';
  static const _theme = 'nazzil.theme.v2';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      language: prefs.getString(_lang) ?? 'system',
      theme: prefs.getString(_theme) ?? _carriedOver(prefs.getString(_oldTheme)),
      palette: prefs.getString(_palette) ?? 'rose',
    );
  }

  /// Dark is the default now. Someone who picked light or dark keeps it; a
  /// stored "system" was the old default as often as a choice, so it moves to dark.
  static String _carriedOver(String? old) => old == 'light' ? 'light' : 'dark';

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lang, settings.language);
    await prefs.setString(_theme, settings.theme);
    await prefs.setString(_palette, settings.palette);
  }
}
