import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_state.dart';

/// Local storage for best score, saved game and settings.
class Storage {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Best score in classic mode (the key 1.0 used).
  static int get best => _prefs.getInt('best') ?? 0;
  static set best(int v) => _prefs.setInt('best', v);

  /// Each mode keeps its own record.
  static int bestFor(GameMode m) => m == GameMode.classic ? best : _prefs.getInt('best_${m.name}') ?? 0;
  static void setBestFor(GameMode m, int v) => m == GameMode.classic ? best = v : _prefs.setInt('best_${m.name}', v);

  /// Heat mode explains its rules once.
  static bool get heatTutorialSeen => _prefs.getBool('heatTutorialSeen') ?? false;
  static set heatTutorialSeen(bool v) => _prefs.setBool('heatTutorialSeen', v);

  /// Index into BlockPattern.values.
  static int get pattern => _prefs.getInt('pattern') ?? 0;
  static set pattern(int v) => _prefs.setInt('pattern', v);

  static bool get haptics => _prefs.getBool('haptics') ?? true;
  static set haptics(bool v) => _prefs.setBool('haptics', v);

  static bool get sound => _prefs.getBool('sound') ?? true;
  static set sound(bool v) => _prefs.setBool('sound', v);

  static bool get music => _prefs.getBool('music') ?? true;
  static set music(bool v) => _prefs.setBool('music', v);

  /// 0 follows the phone, 1 Turkish, 2 English.
  static int get language => _prefs.getInt('language') ?? 0;
  static set language(int v) => _prefs.setInt('language', v);

  /// Index into Sound.packs.
  static int get soundPack => _prefs.getInt('soundPack') ?? 0;
  static set soundPack(int v) => _prefs.setInt('soundPack', v);

  static bool get tutorialSeen => _prefs.getBool('tutorialSeen') ?? false;
  static set tutorialSeen(bool v) => _prefs.setBool('tutorialSeen', v);

  static int get gamesPlayed => _prefs.getInt('gamesPlayed') ?? 0;
  static set gamesPlayed(int v) => _prefs.setInt('gamesPlayed', v);

  /// Classic keeps the 1.0 key so a game saved before the update resumes.
  static String _saveKey(GameMode m) => m == GameMode.classic ? 'savedGame' : 'savedGame_${m.name}';

  static void saveGame(GameState g) => _prefs.setString(_saveKey(g.mode), jsonEncode(g.toJson()));

  static void clearSavedGame([GameMode m = GameMode.classic]) => _prefs.remove(_saveKey(m));

  static GameState? loadGame([GameMode m = GameMode.classic]) {
    final s = _prefs.getString(_saveKey(m));
    if (s == null) return null;
    final g = GameState.fromJson(jsonDecode(s) as Map<String, dynamic>);
    if (g == null || g.gameOver || g.mode != m) return null;
    return g;
  }

  static bool hasSavedGame([GameMode m = GameMode.classic]) => loadGame(m) != null;
}
