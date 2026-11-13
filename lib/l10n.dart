import 'dart:ui';

import 'services/storage.dart';

/// Turkish and English text. Turkish strings are written in the code and
/// looked up here when the game runs in English.
///
/// The language follows the phone (Turkish phones get Turkish, every other
/// language gets English) unless the player picks one in settings.
class Lang {
  /// Names shown in settings: automatic, Turkish, English.
  static const options = ['Otomatik', 'Türkçe', 'English'];

  static bool get english => switch (Storage.language) {
    1 => false,
    2 => true,
    _ => PlatformDispatcher.instance.locale.languageCode != 'tr',
  };
}

/// Translates a fixed Turkish string.
String tx(String turkish) => Lang.english ? (_en[turkish] ?? turkish) : turkish;

/// Picks between two texts that hold numbers or names.
String pick(String turkish, String english) => Lang.english ? english : turkish;

/// Every fixed Turkish string and its English text.
const en = _en;

const _en = <String, String>{
  // Home and settings.
  'Ayarlar': 'Settings',
  'Ses efektleri': 'Sound effects',
  'Ses paketi': 'Sound pack',
  'Klasik': 'Classic',
  'Arcade': 'Arcade',
  'Pop': 'Pop',
  'Müzik': 'Music',
  'Titreşim': 'Vibration',
  'Dil': 'Language',
  'Otomatik': 'Automatic',
  'Tahta fotoğrafı': 'Board picture',
  'Öğreticiyi tekrar göster': 'Show the tutorial again',
  'Gizlilik politikası': 'Privacy policy',
  'Destek': 'Support',
  'Buzdan başla, seriyle alevlen': 'Start cold, catch fire',
  'Klasik mod · Devam et': 'Classic mode · Continue',
  'Klasik mod': 'Classic mode',
  'Yeni oyun': 'New game',
  'Sıfırla': 'Reset',
  'Rekor': 'Best',
  'Blok deseni': 'Block pattern',
  // Board pictures.
  'Gün batımı': 'Sunset',
  'Dağlar': 'Mountains',
  'Yıldızlı gece': 'Starry night',
  'Çiçek tarlası': 'Flower field',
  'Okyanus': 'Ocean',
  'Kuzey ışıkları': 'Northern lights',
  'Sakura': 'Sakura',
  'Çöl': 'Desert',
  'Gökkuşağı': 'Rainbow',
  'Sonbahar ormanı': 'Autumn forest',
  'Şehir gecesi': 'City at night',
  'Mercan resifi': 'Coral reef',
  'Kendi fotoğrafın': 'Your photo',
  'Yok': 'None',
  'Fotoğraf açılamadı. Başka bir fotoğraf dene.': "Couldn't open that photo. Try another one.",
  'Bloklar yerleştikçe resim tahtada ortaya çıkar.': 'The picture shows through as you place blocks.',
  'Galeriden seç': 'Choose from gallery',
  'Şu an kendi fotoğrafın kullanılıyor.': 'Your own photo is on the board.',
  'Hazır resimler': 'Ready-made pictures',
  // Skins and patterns.
  'Neon': 'Neon',
  'Buz': 'Ice',
  'Magma': 'Magma',
  'Kristal': 'Crystal',
  'Düz': 'Plain',
  'Çizgili': 'Striped',
  'Puantiyeli': 'Dotted',
  'Kareli': 'Checked',
  'Dalgalı': 'Wavy',
  'Yıldızlı': 'Starry',
  // Game.
  'YENİ REKOR!': 'NEW RECORD!',
  'Görev tamam!': 'Goal complete!',
  'seri': 'streak',
  'Seri': 'Streak',
  'yeni görünüm': 'new look',
  'görev': 'goal',
  'Parçayı sürükle': 'Drag a piece',
  'Alttaki 3 parçadan birini tut ve tahtaya sürükle. Parçalar döndürülemez.':
      'Hold one of the 3 pieces below and drag it onto the board. Pieces cannot be rotated.',
  'Çizgiyi doldur': 'Fill a line',
  'Bir satır ya da sütun tamamen dolunca patlayarak temizlenir.': 'A full row or column blows up and clears.',
  'Seriyi sürdür': 'Keep the streak',
  'Aynı anda birden fazla çizgi temizle ve art arda temizleyerek puanını katla.':
      'Clear several lines at once and keep clearing move after move to multiply your score.',
  'İleri': 'Next',
  'Başla': 'Start',
  'Duraklatıldı': 'Paused',
  'Devam et': 'Continue',
  'Yeniden başla': 'Restart',
  'Ana menü': 'Main menu',
  'REKOR': 'BEST',
  'KLASİK': 'CLASSIC',
  'Duraklat': 'Pause',
  '🔥 Yeni rekor': '🔥 New record',
  'Yeni rekor!': 'New record!',
  'Yer kalmadı': 'No room left',
  'Reklam izle, devam et': 'Watch an ad to continue',
  'Tekrar oyna': 'Play again',
  // Heat.
  'Soğuk': 'Cold',
  'Ilık': 'Warm',
  'Sıcak': 'Hot',
  'Kızgın': 'Blazing',
  'Alev!': 'On fire!',
  // Praise.
  'Tahta tertemiz!': 'Board clear!',
  'İnanılmaz!': 'Incredible!',
  'Efsane!': 'Legendary!',
  'Muhteşem!': 'Amazing!',
  'Yanıyorsun!': "You're on fire!",
  'Durdurulamaz!': 'Unstoppable!',
  'Harika!': 'Great!',
  'Süper!': 'Super!',
  'Güzel!': 'Nice!',
  // Heat mode.
  'Isı modu': 'Heat mode',
  'Isı modu · Devam et': 'Heat mode · Continue',
  'Donmuş hücreler ve yayılan ateş': 'Frozen cells and spreading fire',
  'YENİ': 'NEW',
  'ISI': 'HEAT',
  'söndü': 'put out',
  'Buz eridi!': 'Meltdown!',
  'Yangın söndü!': 'Fire out!',
  'Söndürüldü!': 'Doused!',
  'Buz çözüldü!': 'Ice broken!',
  'Çizgileri doldurup patlat. Ama bu tahtada buz ve ateş de var.':
      'Fill lines to blast them. But this board has ice and fire too.',
  'Donmuş hücre': 'Frozen cell',
  'Buzun üstüne parça konmaz. Yanındaki ya da içindeki çizgi patlayınca çatlar ve erir.':
      'You cannot place on ice. It cracks and melts when a line through it or next to it clears.',
  'Yanan blok': 'Burning block',
  'Sayaç bitince ateş yan hücreye sıçrar ve tahtayı doldurur. Bloğun çizgisini patlatıp söndür.':
      'When its counter runs out, the fire jumps to the next cell and fills your board. Clear its line to put it out.',
  'Isıyı kullan': 'Use the heat',
  '4 hamle üst üste çizgi patlatırsan seri kızışır ve dokunduğun buzlar tek seferde erir. Ateş buza sıçrarsa ikisi de söner.': 'Clear lines 4 moves in a row and your streak gets hot enough to melt ice in one hit. Fire that jumps onto ice dies out with it.',
  'Klasik rekor': 'Classic best',
  'Isı rekoru': 'Heat best',
  // Goals.
  "3'lü seri yap": 'Get a 3x streak',
  'Aynı anda 2 çizgi': '2 lines at once',
  'Aynı anda 3 çizgi': '3 lines at once',
  '10 çizgi patlat': 'Blast 10 lines',
  'Tek hamlede 100 puan': '100 points in one move',
  "5'li seri yap": 'Get a 5x streak',
  '5 buz çöz': 'Melt 5 ice',
  '2 ateş söndür': 'Put out 2 fires',
  '12 buz çöz': 'Melt 12 ice',
  '5 ateş söndür': 'Put out 5 fires',
};
