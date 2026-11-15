import '../game/game_config.dart';

/// Monetization switches.
///
/// The on/off values come from Firebase Remote Config (see [GameConfig]), so
/// ads can be switched on later without an app update. Until Firebase answers,
/// or when it can't be reached, everything stays off.
class Monetization {
  /// Set to true in the release that actually contains the Google AdMob code.
  /// Until then remote switches can't show an ad button that does nothing.
  static const bool adsBuiltIn = false;

  static GameConfig get _c => GameConfig.current;

  /// Master switch for all ads.
  static bool get adsEnabled => adsBuiltIn && _c.adsEnabled && !removeAdsPurchased;

  /// "Watch an ad, continue with 3 new pieces" on the game over screen.
  static bool get rewardedContinueEnabled => adsEnabled && _c.rewardedContinueEnabled;

  /// Full-screen ad after every N finished games (never in the first few).
  static bool get interstitialEnabled => adsEnabled && _c.interstitialEnabled;
  static int get interstitialEveryNGames => _c.interstitialEveryNGames;

  /// Whether the player bought "remove ads".
  static bool removeAdsPurchased = false;

  static bool get canOfferContinue => rewardedContinueEnabled;

  /// Should a full-screen ad follow the game that just ended?
  /// [gamesPlayed] counts finished games including this one.
  static bool shouldShowInterstitial(int gamesPlayed) {
    if (!interstitialEnabled) return false;
    if (gamesPlayed <= _c.interstitialMinGames) return false;
    return gamesPlayed % _c.interstitialEveryNGames == 0;
  }
}
