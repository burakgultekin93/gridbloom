/// Monetization switches.
///
/// Version 1 ships with every flag off. In step 3 these values will be read
/// from Firebase Remote Config, so ads can be switched on without an app
/// update. Google AdMob and in-app purchase code plugs in behind these flags.
class Monetization {
  /// Master switch for all ads.
  static bool adsEnabled = false;

  /// "Watch an ad, continue with 3 new pieces" on the game over screen.
  static bool rewardedContinueEnabled = false;

  /// Full-screen ad after every N finished games (never in the first 2).
  static bool interstitialEnabled = false;
  static int interstitialEveryNGames = 3;

  /// Whether the player bought "remove ads".
  static bool removeAdsPurchased = false;

  static bool get canOfferContinue => adsEnabled && rewardedContinueEnabled;
}
