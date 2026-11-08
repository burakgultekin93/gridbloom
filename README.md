# Gridbloom

A calm block puzzle for iOS and Android, built with Flutter. Place pieces on an 8x8 garden; full rows and columns bloom into flowers and clear.

## Run

```bash
flutter pub get
flutter test          # game rule tests
flutter run           # on a connected phone or emulator
flutter build web --no-web-resources-cdn   # browser test build
```

## Layout

- `lib/game/` pure game rules: pieces, board, scoring, piece generation, save/load
- `lib/ui/` screens and painters
- `lib/services/storage.dart` best score, saved game, settings
- `lib/services/monetization.dart` ad switches, all off in v1 (to be driven by Firebase Remote Config)

Font: Nunito, SIL Open Font License (`assets/fonts/OFL.txt`).
