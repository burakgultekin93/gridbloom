import 'dart:convert';

import 'pieces.dart';

/// Every value that can be tuned from Firebase Remote Config without an
/// app update.
///
/// The defaults below are exactly the values version 1.0 shipped with, so a
/// phone that has never reached Firebase (first launch offline, Firebase not
/// set up yet, a fetch error) plays the same game as before.
///
/// Remote values are checked one by one: a missing key, a wrong type or a
/// value outside its safe range falls back to the default for that key only,
/// so a typo in the Firebase console can never break the game.
class GameConfig {
  // ---- Difficulty phases ----

  /// Below this score no large pieces appear and trays are extra kind.
  final int warmupScore;

  /// From this score large pieces get more common (the hard phase).
  final int hardScore;

  /// Board fill (0..1) above which the "rescue" help starts.
  final double rescueFill;

  // ---- Piece generation weights ----

  final int weightSmall;
  final int weightSmallRescue;
  final int weightMedium;
  final int weightLargeRescue;

  /// Large piece weight in the normal phase: base + score / step.
  final int weightLargeNormalBase;
  final int weightLargeNormalStep;

  /// Large piece weight in the hard phase: base + min((score - hardScore) / step, maxExtra).
  final int weightLargeHardBase;
  final int weightLargeHardStep;
  final int weightLargeHardMaxExtra;

  /// Per-piece multipliers by piece id, for example {"o3": 0.5}. 0 turns a
  /// piece off. Pieces not listed keep a multiplier of 1.
  final Map<String, double> pieceWeightMultipliers;

  // ---- Hidden assist ----

  /// Master switch for the quiet help. Off means pure random trays.
  final bool assistEnabled;
  final double assistWarmup;
  final double assistRescue;
  final double assistRecord;

  /// Record chase help only when the record is below this score.
  final int recordAssistMaxBest;

  /// How many extra candidate trays full assist looks at.
  final int assistExtraTrays;

  // ---- Ads (step 4) ----

  final bool adsEnabled;
  final bool rewardedContinueEnabled;
  final bool interstitialEnabled;
  final int interstitialEveryNGames;

  /// No full-screen ad until the player has finished this many games.
  final int interstitialMinGames;

  // ---- Feature flags ----

  /// Free-form switches for future features, for example {"new_mode": true}.
  final Map<String, bool> featureFlags;

  const GameConfig({
    this.warmupScore = 800,
    this.hardScore = 3000,
    this.rescueFill = 0.65,
    this.weightSmall = 6,
    this.weightSmallRescue = 12,
    this.weightMedium = 4,
    this.weightLargeRescue = 1,
    this.weightLargeNormalBase = 1,
    this.weightLargeNormalStep = 1500,
    this.weightLargeHardBase = 3,
    this.weightLargeHardStep = 2000,
    this.weightLargeHardMaxExtra = 3,
    this.pieceWeightMultipliers = const {},
    this.assistEnabled = true,
    this.assistWarmup = 1.0,
    this.assistRescue = 0.8,
    this.assistRecord = 0.6,
    this.recordAssistMaxBest = 20000,
    this.assistExtraTrays = 8,
    this.adsEnabled = false,
    this.rewardedContinueEnabled = false,
    this.interstitialEnabled = false,
    this.interstitialEveryNGames = 3,
    this.interstitialMinGames = 2,
    this.featureFlags = const {},
  });

  static const GameConfig defaults = GameConfig();

  /// The config new games start with. Remote Config replaces it after a
  /// successful fetch; a game in progress keeps the config it started with.
  static GameConfig current = defaults;

  bool flag(String name) => featureFlags[name] ?? false;

  /// Base weight for a piece size at [score]; [rescue] when the board is crowded.
  int sizeWeight(PieceSize size, int score, {required bool rescue}) {
    switch (size) {
      case PieceSize.small:
        return rescue ? weightSmallRescue : weightSmall;
      case PieceSize.medium:
        return weightMedium;
      case PieceSize.large:
        if (score < warmupScore) return 0; // none during warm-up
        if (rescue) return weightLargeRescue;
        if (score < hardScore) return weightLargeNormalBase + score ~/ weightLargeNormalStep;
        final extra = (score - hardScore) ~/ weightLargeHardStep;
        return weightLargeHardBase + (extra < weightLargeHardMaxExtra ? extra : weightLargeHardMaxExtra);
    }
  }

  /// Key names as they are written in the Firebase console.
  static const kWarmupScore = 'warmup_score';
  static const kHardScore = 'hard_score';
  static const kRescueFill = 'rescue_fill';
  static const kWeightSmall = 'weight_small';
  static const kWeightSmallRescue = 'weight_small_rescue';
  static const kWeightMedium = 'weight_medium';
  static const kWeightLargeRescue = 'weight_large_rescue';
  static const kWeightLargeNormalBase = 'weight_large_normal_base';
  static const kWeightLargeNormalStep = 'weight_large_normal_step';
  static const kWeightLargeHardBase = 'weight_large_hard_base';
  static const kWeightLargeHardStep = 'weight_large_hard_step';
  static const kWeightLargeHardMaxExtra = 'weight_large_hard_max_extra';
  static const kPieceWeightMultipliers = 'piece_weight_multipliers';
  static const kAssistEnabled = 'assist_enabled';
  static const kAssistWarmup = 'assist_warmup';
  static const kAssistRescue = 'assist_rescue';
  static const kAssistRecord = 'assist_record';
  static const kRecordAssistMaxBest = 'record_assist_max_best';
  static const kAssistExtraTrays = 'assist_extra_trays';
  static const kAdsEnabled = 'ads_enabled';
  static const kRewardedContinueEnabled = 'rewarded_continue_enabled';
  static const kInterstitialEnabled = 'interstitial_enabled';
  static const kInterstitialEveryNGames = 'interstitial_every_n_games';
  static const kInterstitialMinGames = 'interstitial_min_games';
  static const kFeatureFlags = 'feature_flags';

  /// Defaults in the shape Remote Config's setDefaults expects.
  Map<String, Object> toMap() => {
    kWarmupScore: warmupScore,
    kHardScore: hardScore,
    kRescueFill: rescueFill,
    kWeightSmall: weightSmall,
    kWeightSmallRescue: weightSmallRescue,
    kWeightMedium: weightMedium,
    kWeightLargeRescue: weightLargeRescue,
    kWeightLargeNormalBase: weightLargeNormalBase,
    kWeightLargeNormalStep: weightLargeNormalStep,
    kWeightLargeHardBase: weightLargeHardBase,
    kWeightLargeHardStep: weightLargeHardStep,
    kWeightLargeHardMaxExtra: weightLargeHardMaxExtra,
    kPieceWeightMultipliers: jsonEncode(pieceWeightMultipliers),
    kAssistEnabled: assistEnabled,
    kAssistWarmup: assistWarmup,
    kAssistRescue: assistRescue,
    kAssistRecord: assistRecord,
    kRecordAssistMaxBest: recordAssistMaxBest,
    kAssistExtraTrays: assistExtraTrays,
    kAdsEnabled: adsEnabled,
    kRewardedContinueEnabled: rewardedContinueEnabled,
    kInterstitialEnabled: interstitialEnabled,
    kInterstitialEveryNGames: interstitialEveryNGames,
    kInterstitialMinGames: interstitialMinGames,
    kFeatureFlags: jsonEncode(featureFlags),
  };

  /// Builds a config from raw values (strings as Remote Config stores them,
  /// or numbers/bools). Anything unusable falls back to the default.
  factory GameConfig.fromMap(Map<String, Object?> m) {
    const d = defaults;
    int i(String k, int def, int lo, int hi) {
      final v = _num(m[k]);
      if (v == null || v != v.roundToDouble()) return def;
      final n = v.toInt();
      return n < lo || n > hi ? def : n;
    }

    double f(String k, double def, double lo, double hi) {
      final v = _num(m[k]);
      if (v == null || v.isNaN || v < lo || v > hi) return def;
      return v.toDouble();
    }

    bool b(String k, bool def) => _bool(m[k]) ?? def;

    var warmup = i(kWarmupScore, d.warmupScore, 0, 100000);
    var hard = i(kHardScore, d.hardScore, 0, 1000000);
    // Warm-up must end before the hard phase starts.
    if (hard < warmup) (warmup, hard) = (d.warmupScore, d.hardScore);

    final c = GameConfig(
      warmupScore: warmup,
      hardScore: hard,
      rescueFill: f(kRescueFill, d.rescueFill, 0.3, 1.0),
      weightSmall: i(kWeightSmall, d.weightSmall, 0, 100),
      weightSmallRescue: i(kWeightSmallRescue, d.weightSmallRescue, 0, 100),
      weightMedium: i(kWeightMedium, d.weightMedium, 0, 100),
      weightLargeRescue: i(kWeightLargeRescue, d.weightLargeRescue, 0, 100),
      weightLargeNormalBase: i(kWeightLargeNormalBase, d.weightLargeNormalBase, 0, 100),
      weightLargeNormalStep: i(kWeightLargeNormalStep, d.weightLargeNormalStep, 1, 1000000),
      weightLargeHardBase: i(kWeightLargeHardBase, d.weightLargeHardBase, 0, 100),
      weightLargeHardStep: i(kWeightLargeHardStep, d.weightLargeHardStep, 1, 1000000),
      weightLargeHardMaxExtra: i(kWeightLargeHardMaxExtra, d.weightLargeHardMaxExtra, 0, 100),
      pieceWeightMultipliers: _multipliers(m[kPieceWeightMultipliers]),
      assistEnabled: b(kAssistEnabled, d.assistEnabled),
      assistWarmup: f(kAssistWarmup, d.assistWarmup, 0, 1),
      assistRescue: f(kAssistRescue, d.assistRescue, 0, 1),
      assistRecord: f(kAssistRecord, d.assistRecord, 0, 1),
      recordAssistMaxBest: i(kRecordAssistMaxBest, d.recordAssistMaxBest, 0, 10000000),
      assistExtraTrays: i(kAssistExtraTrays, d.assistExtraTrays, 0, 20),
      adsEnabled: b(kAdsEnabled, d.adsEnabled),
      rewardedContinueEnabled: b(kRewardedContinueEnabled, d.rewardedContinueEnabled),
      interstitialEnabled: b(kInterstitialEnabled, d.interstitialEnabled),
      interstitialEveryNGames: i(kInterstitialEveryNGames, d.interstitialEveryNGames, 1, 100),
      interstitialMinGames: i(kInterstitialMinGames, d.interstitialMinGames, 0, 1000),
      featureFlags: _flags(m[kFeatureFlags]),
    );
    // Every phase must be able to draw at least one piece.
    if (!c._canDrawEverywhere()) return defaults;
    return c;
  }

  /// Final weight of one piece, after its multiplier.
  int pieceWeight(PieceShape s, int score, {required bool rescue}) {
    final base = sizeWeight(s.size, score, rescue: rescue);
    final m = pieceWeightMultipliers[s.id];
    if (m == null) return base;
    return (base * m).round();
  }

  bool _canDrawEverywhere() {
    // Warm-up, normal, hard and rescue (in every phase) need a non-zero total.
    for (final score in [0, warmupScore, hardScore, hardScore + 1000000]) {
      for (final rescue in [false, true]) {
        final total = allPieces.fold<int>(0, (a, s) => a + pieceWeight(s, score, rescue: rescue));
        if (total <= 0) return false;
      }
    }
    return true;
  }

  static num? _num(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  static bool? _bool(Object? v) {
    if (v is bool) return v;
    if (v is String) {
      switch (v.trim().toLowerCase()) {
        case 'true' || '1' || 'yes' || 'on':
          return true;
        case 'false' || '0' || 'no' || 'off':
          return false;
      }
    }
    return null;
  }

  static Object? _json(Object? v) {
    if (v is Map) return v;
    if (v is! String || v.trim().isEmpty) return null;
    try {
      return jsonDecode(v);
    } catch (_) {
      return null;
    }
  }

  static Map<String, double> _multipliers(Object? v) {
    final j = _json(v);
    if (j is! Map) return const {};
    final out = <String, double>{};
    j.forEach((k, val) {
      final n = _num(val);
      if (k is String && piecesById.containsKey(k) && n != null && n >= 0 && n <= 10) {
        out[k] = n.toDouble();
      }
    });
    return Map.unmodifiable(out);
  }

  static Map<String, bool> _flags(Object? v) {
    final j = _json(v);
    if (j is! Map) return const {};
    final out = <String, bool>{};
    j.forEach((k, val) {
      final b = _bool(val);
      if (k is String && b != null) out[k] = b;
    });
    return Map.unmodifiable(out);
  }
}
