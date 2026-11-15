import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:blazegrid/game/game_config.dart';
import 'package:blazegrid/game/game_state.dart';
import 'package:blazegrid/game/pieces.dart';
import 'package:blazegrid/services/monetization.dart';

void main() {
  tearDown(() => GameConfig.current = GameConfig.defaults);

  test('defaults round-trip through the Remote Config map', () {
    final raw = GameConfig.defaults.toMap().map((k, v) => MapEntry(k, '$v'));
    final c = GameConfig.fromMap(raw);
    expect(c.toMap(), GameConfig.defaults.toMap());
  });

  test('defaults keep the 1.0 piece weights', () {
    const c = GameConfig.defaults;
    int w(PieceSize s, int score, [bool rescue = false]) => c.sizeWeight(s, score, rescue: rescue);
    expect(w(PieceSize.small, 0), 6);
    expect(w(PieceSize.small, 0, true), 12);
    expect(w(PieceSize.medium, 5000), 4);
    expect(w(PieceSize.large, 500), 0);
    expect(w(PieceSize.large, 1000, true), 1);
    expect(w(PieceSize.large, 1000), 1);
    expect(w(PieceSize.large, 2000), 2);
    expect(w(PieceSize.large, 3000), 3);
    expect(w(PieceSize.large, 7100), 5);
    expect(w(PieceSize.large, 50000), 6);
  });

  test('empty or broken remote values fall back to defaults', () {
    expect(GameConfig.fromMap({}).toMap(), GameConfig.defaults.toMap());
    final c = GameConfig.fromMap({
      'warmup_score': 'abc',
      'rescue_fill': '7',
      'weight_small': '-3',
      'weight_medium': '2.5',
      'ads_enabled': 'maybe',
      'piece_weight_multipliers': '{not json',
      'feature_flags': '[1,2]',
    });
    expect(c.toMap(), GameConfig.defaults.toMap());
  });

  test('valid remote values are used', () {
    final c = GameConfig.fromMap({
      'warmup_score': '500',
      'hard_score': '2000',
      'weight_small': 9,
      'assist_enabled': 'false',
      'ads_enabled': true,
      'piece_weight_multipliers': '{"o3": 0, "dot": 2, "nope": 5}',
      'feature_flags': '{"new_mode": true, "bad": "x"}',
    });
    expect(c.warmupScore, 500);
    expect(c.hardScore, 2000);
    expect(c.weightSmall, 9);
    expect(c.assistEnabled, isFalse);
    expect(c.adsEnabled, isTrue);
    expect(c.pieceWeightMultipliers, {'o3': 0.0, 'dot': 2.0});
    expect(c.pieceWeight(piecesById['o3']!, 5000, rescue: false), 0);
    expect(c.pieceWeight(piecesById['dot']!, 0, rescue: false), 18);
    expect(c.flag('new_mode'), isTrue);
    expect(c.flag('bad'), isFalse);
  });

  test('hard phase before warm-up resets both phases', () {
    final c = GameConfig.fromMap({'warmup_score': '5000', 'hard_score': '1000'});
    expect(c.warmupScore, 800);
    expect(c.hardScore, 3000);
  });

  test('weights that could never draw a piece are rejected', () {
    final c = GameConfig.fromMap({'weight_small': 0, 'weight_medium': 0, 'weight_small_rescue': 0});
    expect(c.toMap(), GameConfig.defaults.toMap());
  });

  test('a game keeps the config it started with', () {
    GameConfig.current = GameConfig.fromMap({'assist_enabled': 'false'});
    final g = GameState(rng: Random(1));
    GameConfig.current = GameConfig.defaults;
    expect(g.config.assistEnabled, isFalse);
    expect(g.assist, 0);
    expect(GameState(rng: Random(1)).assist, greaterThan(0));
  });

  test('turning a piece off remotely keeps it out of trays', () {
    final multipliers = {for (final p in allPieces) if (p.id != 'dot') p.id: 0};
    final c = GameConfig.fromMap({'piece_weight_multipliers': '{${multipliers.keys.map((k) => '"$k":0').join(',')}}'});
    final g = GameState(rng: Random(4), config: c);
    expect(g.tray.every((p) => p!.shape.id == 'dot'), isTrue);
  });

  test('ads stay off until the ad code ships, whatever Remote Config says', () {
    GameConfig.current = GameConfig.fromMap({
      'ads_enabled': 'true',
      'rewarded_continue_enabled': 'true',
      'interstitial_enabled': 'true',
    });
    expect(Monetization.canOfferContinue, Monetization.adsBuiltIn);
    expect(Monetization.shouldShowInterstitial(3), Monetization.adsBuiltIn);
    expect(Monetization.shouldShowInterstitial(2), isFalse); // first games are ad free
  });
}
