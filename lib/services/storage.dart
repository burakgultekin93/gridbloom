import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_state.dart';

/// Local storage for best score, saved game and settings.
class Storage {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static int get best => _prefs.getInt('best') ?? 0;
  static set best(int v) => _prefs.setInt('best', v);

  static bool get haptics => _prefs.getBool('haptics') ?? true;
  static set haptics(bool v) => _prefs.setBool('haptics', v);

  static bool get tutorialSeen => _prefs.getBool('tutorialSeen') ?? false;
  static set tutorialSeen(bool v) => _prefs.setBool('tutorialSeen', v);

  static int get gamesPlayed => _prefs.getInt('gamesPlayed') ?? 0;
  static set gamesPlayed(int v) => _prefs.setInt('gamesPlayed', v);

  static void saveGame(GameState g) =>
      _prefs.setString('savedGame', jsonEncode(g.toJson()));

  static void clearSavedGame() => _prefs.remove('savedGame');

  static GameState? loadGame() {
    final s = _prefs.getString('savedGame');
    if (s == null) return null;
    final g = GameState.fromJson(jsonDecode(s) as Map<String, dynamic>);
    if (g == null || g.gameOver) return null;
    return g;
  }

  static bool get hasSavedGame => loadGame() != null;
}
