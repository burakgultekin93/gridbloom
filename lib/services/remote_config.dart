import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../game/game_config.dart';

/// Loads [GameConfig] from Firebase Remote Config.
///
/// Never blocks the game: startup waits at most a moment for Firebase to
/// start, uses the values saved on the phone from the last successful fetch
/// (or the built-in defaults), and fetches fresh values in the background.
/// New values apply from the next game. Offline, or when Firebase isn't set
/// up yet, the game just keeps the defaults.
class RemoteConfigService {
  static bool _ready = false;

  /// True once Firebase answered at least once in this session.
  static bool get ready => _ready;

  static Future<void> init() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) {
      debugPrint('Remote Config: Firebase not set up, using defaults');
      return;
    }
    try {
      await Firebase.initializeApp(options: options).timeout(const Duration(seconds: 3));
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // Debug builds refresh quickly so changes can be tried out.
          minimumFetchInterval: kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 1),
        ),
      );
      await rc.setDefaults(GameConfig.defaults.toMap());
      // Values fetched on an earlier launch are already on the phone.
      _apply(rc);
      unawaited(_refresh(rc));
      _listen(rc);
    } catch (e) {
      debugPrint('Remote Config: start failed, using defaults ($e)');
    }
  }

  static Future<void> _refresh(FirebaseRemoteConfig rc) async {
    try {
      await rc.fetchAndActivate();
      _ready = true;
      _apply(rc);
    } catch (e) {
      debugPrint('Remote Config: fetch failed, keeping current values ($e)');
    }
  }

  /// Real-time updates while the app is open (published changes arrive
  /// within seconds instead of waiting for the next fetch).
  static void _listen(FirebaseRemoteConfig rc) {
    try {
      rc.onConfigUpdated.listen(
        (_) async {
          try {
            await rc.activate();
            _apply(rc);
          } catch (e) {
            debugPrint('Remote Config: update failed ($e)');
          }
        },
        onError: (Object e) => debugPrint('Remote Config: live updates off ($e)'),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Remote Config: live updates off ($e)');
    }
  }

  static void _apply(FirebaseRemoteConfig rc) {
    final values = {for (final e in rc.getAll().entries) e.key: e.value.asString()};
    GameConfig.current = GameConfig.fromMap(values);
  }
}
