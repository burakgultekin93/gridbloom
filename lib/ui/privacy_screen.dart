import 'package:flutter/material.dart';

import '../l10n.dart';
import 'palette.dart';

/// The privacy policy, shown inside the app. The same text is published on
/// the web for the store listing (docs/privacy.html).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sectionsTr = <(String, String)>[
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

  static const _sectionsEn = <(String, String)>[
    ('Data controller', 'Burak Gültekin. Contact: avburakgultekin@icloud.com'),
    (
      'Data we collect',
      'This version of the game collects no personal data, sends nothing to a server and shares '
          'nothing with third parties. There is no account, sign-in or registration.\n\n'
          'Your best score, unfinished game, settings and the photo you pick for the board are stored '
          'only on your device. The photo is scaled down, never uploaded, and can be removed with "Reset". '
          'Deleting the game deletes all of this from your device.',
    ),
    (
      'Permissions',
      'The game opens the photo picker only when you tap "Choose from gallery". '
          'It does not access the rest of your library.',
    ),
    (
      'Ads',
      'This version has no ads. If ads are added later, this policy will be updated first and your '
          'consent will be asked where required.',
    ),
    (
      'Your rights',
      'To use your rights under the GDPR and Turkish data protection law (KVKK), or to ask a question, '
          'contact us at the address above.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      appBar: AppBar(
        backgroundColor: Palette.background,
        foregroundColor: Palette.soil,
        title: Text(tx('Gizlilik politikası')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            pick(
              'Bu metin, Blazegrid oyununun kişisel verileri nasıl işlediğini KVKK ve GDPR kapsamında açıklar.',
              'This explains how the Blazegrid game handles personal data under the GDPR and KVKK.',
            ),
            style: const TextStyle(color: Palette.soilLight, fontSize: 15, height: 1.5),
          ),
          for (final (title, body) in Lang.english ? _sectionsEn : _sectionsTr) ...[
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
