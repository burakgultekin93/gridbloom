import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'storage.dart';

/// Sound effects and background music. All audio is synthesized by
/// tool/gen_sounds.py, so it is original to the game.
///
/// Sounds mix with the player's own music and follow the silent switch on
/// iPhone (ambient audio session).
class Sound {
  static final Map<String, AudioPool> _pools = {};
  static final AudioPlayer _music = AudioPlayer(playerId: 'music');
  static bool _ready = false;
  static bool _musicOn = false;

  static const _effects = [
    'place', 'pick', 'big', 'goal', 'gameover', //
    'ice0', 'ice1', 'ice2', 'ice3', 'fire0', 'fire1', 'fire2', 'fire3',
  ];

  /// Selectable sound packs: (folder, name shown in settings).
  static const packs = [('classic', 'Klasik'), ('arcade', 'Arcade'), ('pop', 'Pop')];

  static int get pack => Storage.soundPack.clamp(0, packs.length - 1);

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build(),
      );
      await _loadPack(pack);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.35);
      await _music.setSource(AssetSource('sounds/music.mp3'));
      _ready = true;
    } catch (e) {
      // Audio is a nice-to-have: the game runs silently if it fails.
      debugPrint('Sound init failed: $e');
    }
  }

  static Future<void> _loadPack(int index) async {
    final old = Map.of(_pools);
    _pools.clear();
    final dir = packs[index].$1;
    for (final name in _effects) {
      _pools[name] = await AudioPool.createFromAsset(
        path: 'sounds/$dir/$name.wav',
        maxPlayers: name.startsWith('ice') || name.startsWith('fire') || name == 'place' ? 4 : 2,
      );
    }
    for (final p in old.values) {
      p.dispose().catchError((Object _) {});
    }
  }

  /// Switches to another sound pack and plays a short preview of it.
  static Future<void> setPack(int index) async {
    Storage.soundPack = index;
    if (!_ready) return;
    try {
      await _loadPack(index);
    } catch (e) {
      debugPrint('Sound pack load failed: $e');
      return;
    }
    play('ice1');
    Future.delayed(const Duration(milliseconds: 450), () => play('fire2'));
  }

  static void play(String name, {double volume = 1}) {
    if (!_ready || !Storage.sound) return;
    _pools[name]?.start(volume: volume).catchError((Object _) => () async {});
  }

  /// A line clear: ice while the streak is cold, fire once it is hot. A
  /// longer streak plays a higher variant, so combos climb in pitch.
  static void clear({required bool fire, required int streak, required int lines}) {
    final step = (streak - 1).clamp(0, 3);
    play('${fire ? 'fire' : 'ice'}$step', volume: lines >= 2 ? 1 : 0.8);
  }

  static Future<void> startMusic() async {
    if (!_ready || !Storage.music || _musicOn) return;
    _musicOn = true;
    try {
      await _music.resume();
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
    if (!_ready || !_musicOn) return;
    _musicOn = false;
    try {
      await _music.pause();
    } catch (_) {}
  }

  /// Called when the music setting changes.
  static Future<void> applyMusicSetting() => Storage.music ? startMusic() : stopMusic();
}
