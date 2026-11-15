# Firebase Remote Config kurulumu (Blazegrid v2)

Kod hazır. Firebase kurulmadan da oyun çalışır: o zaman 1.0'daki değerlerle oynar.
Senin yapman gereken tek şey Firebase projesini açıp iki dosyayı indirmek.

## 1. Firebase projesini aç (5 dk)

1. https://console.firebase.google.com adresine Google hesabınla gir.
2. **Proje oluştur** (Create a project) → ad: `Blazegrid` → **Devam**.
3. Google Analytics sorusunda **kapalı** seç (Remote Config için gerekmez, gizlilik etiketi de sade kalır) → **Proje oluştur**.

## 2. iOS uygulamasını ekle

1. Proje ana sayfasında **iOS+** simgesine bas.
2. **Apple paket kimliği** (bundle ID): `com.burakgultekin.blazegrid` (birebir aynı yaz).
3. Takma ad: `Blazegrid`. App Store ID boş kalabilir → **Uygulamayı kaydet**.
4. **GoogleService-Info.plist** dosyasını indir.
5. Sonraki adımları (SDK ekleme, başlatma kodu) **İleri** diyerek geç. Bunlar kodda zaten var.

## 3. Android uygulamasını ekle (şimdilik isteğe bağlı)

1. Proje ayarları → **Uygulama ekle** → Android simgesi.
2. Paket adı: `com.burakgultekin.blazegrid` → **Uygulamayı kaydet**.
3. **google-services.json** dosyasını indir, diğer adımları geç.

## 4. Dosyaları projeye koy

En kolayı: iki dosyayı Masaüstündeki **Claude Uygulama** klasörüne koy ve bana yaz, gerisini ben yaparım.

Kendin yapmak istersen (proje klasöründe, Terminal'de):

1. `GoogleService-Info.plist` → `ios/Runner/` klasörüne kopyala.
2. `google-services.json` → `android/app/` klasörüne kopyala.
3. Şunu çalıştır: `dart run tool/firebase_setup.dart`
   Bu komut `lib/firebase_options.dart` dosyasını doldurur. Xcode'a dosya sürüklemene veya
   Firebase CLI kurmana gerek yok.

## 5. Değerleri Firebase'den değiştir

Firebase konsolu → **Çalıştır (Run)** → **Remote Config** → **Yapılandırma oluştur**.
Sadece değiştirmek istediğin anahtarı ekle; eklemediğin her şey varsayılan değerinde kalır.
Her eklemeden sonra sağ üstten **Değişiklikleri yayınla** demeyi unutma.

Yanlış bir değer yazarsan (harf, aralık dışı sayı, bozuk JSON) oyun o anahtar için varsayılana döner, çökmez.
Yeni değerler **bir sonraki oyunda** geçerli olur; oynanan oyun yarıda değişmez.

### Zorluk

| Anahtar | Tür | Varsayılan | Ne işe yarar |
|---|---|---|---|
| `warmup_score` | Sayı | 800 | Bu puana kadar büyük parça gelmez, eller çok cömert |
| `hard_score` | Sayı | 3000 | Bu puandan sonra büyük parçalar sıklaşır (zor faz) |
| `rescue_fill` | Sayı | 0.65 | Tahta bu oranda dolunca gizli kurtarma yardımı başlar (0.3–1) |
| `assist_enabled` | Boole | true | Gizli yardımın ana şalteri (false = tamamen rastgele) |
| `assist_warmup` | Sayı | 1.0 | Isınma fazındaki yardım gücü (0–1) |
| `assist_rescue` | Sayı | 0.8 | Tahta dolunca yardım gücü (0–1) |
| `assist_record` | Sayı | 0.6 | Rekora yaklaşınca yardım gücü (0–1) |
| `record_assist_max_best` | Sayı | 20000 | Rekor bunun altındaysa rekor yardımı çalışır |
| `assist_extra_trays` | Sayı | 8 | Tam yardımda kaç aday el arasından en iyisi seçilir (0–20) |

### Parça ağırlıkları (büyük sayı = daha sık)

| Anahtar | Varsayılan | Ne işe yarar |
|---|---|---|
| `weight_small` | 6 | Küçük parçalar |
| `weight_small_rescue` | 12 | Tahta doluyken küçük parçalar |
| `weight_medium` | 4 | Orta parçalar |
| `weight_large_rescue` | 1 | Tahta doluyken büyük parçalar |
| `weight_large_normal_base` | 1 | Normal fazda büyük parça başlangıcı |
| `weight_large_normal_step` | 1500 | Normal fazda her bu kadar puanda +1 |
| `weight_large_hard_base` | 3 | Zor fazda büyük parça başlangıcı |
| `weight_large_hard_step` | 2000 | Zor fazda her bu kadar puanda +1 |
| `weight_large_hard_max_extra` | 3 | Zor fazda en fazla bu kadar eklenir |
| `piece_weight_multipliers` | `{}` | Tek tek parça çarpanı (JSON). Örnek: `{"o3": 0.5, "i5h": 0}` 3x3 kareyi yarıya indirir, 5'li yatay çubuğu kapatır |

Parça adları `lib/game/pieces.dart` dosyasında (`dot`, `i2h`, `o2`, `o3`, `i5h`, `bl_a` ...).

### Isı modu

| Anahtar | Varsayılan | Ne işe yarar |
|---|---|---|
| `heat_wave_every` | 6 | Kaç hamlede bir tehlike dalgası gelir (sırayla buz, ateş) |
| `heat_fuse` | 4 | Yanan blok kaç hamle sonra komşusuna sıçrar |
| `heat_start_ice` | 4 | Oyun başında tahtadaki donmuş hücre sayısı |
| `heat_max_fires` | 3 | Bu kadar blok yanarken yeni ateş gelmez |
| `heat_wave_max_fill` | 0.7 | Tahta bundan doluysa yeni buz gelmez |

### Reklamlar (adım 4, şimdilik hepsi kapalı)

| Anahtar | Varsayılan | Ne işe yarar |
|---|---|---|
| `ads_enabled` | false | Tüm reklamların ana şalteri |
| `rewarded_continue_enabled` | false | "Reklam izle, devam et" düğmesi |
| `interstitial_enabled` | false | Oyun arası tam ekran reklam |
| `interstitial_every_n_games` | 3 | Kaç oyunda bir tam ekran reklam |
| `interstitial_min_games` | 2 | İlk kaç oyunda hiç reklam yok |

Not: AdMob kodu eklenene kadar bu şalterleri açsan bile reklam düğmesi görünmez
(`Monetization.adsBuiltIn`). Böylece içi boş bir düğme yanlışlıkla çıkmaz.

### Yeni özellik bayrakları

`feature_flags` (JSON): ileride eklenecek özellikleri uzaktan açıp kapatmak için.
Örnek: `{"yeni_mod": true}`. Kodda `GameConfig.current.flag('yeni_mod')` ile okunur.

## 6. v2'yi göndermeden önce

- **Gizlilik politikası**: `docs/privacy.html` Firebase'i anlatacak şekilde güncellendi. v2 incelemeye gitmeden
  önce yayındaki gizlilik sayfasını bu metinle güncellemeliyiz.
- **App Store Connect → Uygulama Gizliliği**: Firebase kullanımı nedeniyle etiketin gözden geçirilmesi gerekir.
  v2 gönderiminde birlikte bakarız.
- Sürüm numarası 1.1.0 (build 3) olarak ayarlandı.
