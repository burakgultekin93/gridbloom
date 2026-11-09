import 'package:flutter/material.dart';

import 'palette.dart';

/// The privacy policy, shown inside the app. The same text is published on
/// the web for the store listing (docs/privacy.html).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    ('Veri sorumlusu', 'Burak Gültekin. İletişim: avburakgultekin@icloud.com'),
    (
      'Topladığımız veriler',
      'Oyunun bu sürümü hiçbir kişisel veriyi toplamaz, sunucuya göndermez ve üçüncü kişilerle '
          'paylaşmaz. Hesap açma, giriş yapma veya kayıt olma yoktur.\n\n'
          'En yüksek skorun, yarım kalan oyunun, ayarların ve tahta için seçtiğin fotoğraf yalnızca '
          'cihazında saklanır. Fotoğraf küçültülür, hiçbir yere yüklenmez ve "Sıfırla" ile silinebilir. '
          'Oyunu sildiğinde bu bilgilerin tamamı cihazından silinir.',
    ),
    (
      'İzinler',
      'Oyun, yalnızca sen "Galeriden seç" seçeneğine bastığında fotoğraf seçme ekranını açar. '
          'Galerinin geri kalanına erişmez.',
    ),
    (
      'Reklamlar',
      'Bu sürümde reklam yoktur. İleride reklam eklenirse bu politika önceden güncellenecek ve '
          'gerekli yerlerde onayın istenecektir.',
    ),
    (
      'Hakların',
      'KVKK’nın 11. maddesi ve GDPR kapsamındaki haklarını kullanmak veya soru sormak için '
          'yukarıdaki adresten bize ulaşabilirsin.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      appBar: AppBar(
        backgroundColor: Palette.background,
        foregroundColor: Palette.soil,
        title: const Text('Gizlilik politikası'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const Text(
            'Bu metin, Blazegrid oyununun kişisel verileri nasıl işlediğini KVKK ve GDPR kapsamında açıklar.',
            style: TextStyle(color: Palette.soilLight, fontSize: 15, height: 1.5),
          ),
          for (final (title, body) in _sections) ...[
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(color: Palette.soil, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: Palette.soilLight, fontSize: 15, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
