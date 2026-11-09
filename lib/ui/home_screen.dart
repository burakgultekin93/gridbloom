import 'package:flutter/material.dart';

import '../services/photo_store.dart';
import '../services/storage.dart';
import 'game_screen.dart';
import 'painters.dart';
import 'board_picture_sheet.dart';
import 'palette.dart';
import 'skins.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _open({required bool resume}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(resume: resume ? Storage.loadGame() : null)),
    );
    setState(() {});
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.background,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ayarlar',
                  style: TextStyle(color: Palette.soil, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              SwitchListTile(
                title: const Text('Titreşim'),
                value: Storage.haptics,
                activeThumbColor: Palette.leaf,
                onChanged: (v) => set(() => Storage.haptics = v),
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper_rounded, color: Palette.leaf),
                title: const Text('Tahta fotoğrafı'),
                subtitle: Text(boardPictureLabel()),
                onTap: () async {
                  await showBoardPictureSheet(context);
                  set(() {});
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                title: const Text('Öğreticiyi tekrar göster'),
                onTap: () {
                  Storage.tutorialSeen = false;
                  Navigator.pop(ctx);
                },
              ),
              const ListTile(title: Text('Gizlilik politikası'), subtitle: Text('Mağaza sürümünde eklenecek')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSave = Storage.hasSavedGame;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDDEEF8), Color(0xFFF6F1E7), Color(0xFFFFE2C2)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: _settings,
                  icon: const Icon(Icons.settings_rounded, color: Palette.soil, size: 28),
                  tooltip: 'Ayarlar',
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 120, height: 120, child: CustomPaint(painter: LogoPainter())),
                      const SizedBox(height: 20),
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [Color(0xFF3E8FE0), Color(0xFF8B5CF0), Color(0xFFFF6A2A), Color(0xFFD7301F)],
                        ).createShader(r),
                        child: const Text(
                          'Blazegrid',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const Text(
                        'Buzdan başla, seriyle alevlen',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Palette.soilLight, fontSize: 16),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF0642C),
                            padding: const EdgeInsets.all(18),
                          ),
                          onPressed: () => _open(resume: hasSave),
                          child: Text(
                            hasSave ? 'Klasik mod · Devam et' : 'Klasik mod',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      if (hasSave)
                        TextButton(
                          onPressed: () {
                            Storage.clearSavedGame();
                            _open(resume: false);
                          },
                          child: const Text('Yeni oyun', style: TextStyle(color: Palette.soil)),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await showBoardPictureSheet(context);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.wallpaper_rounded, color: Palette.leaf),
                            label: Text(
                              'Tahta fotoğrafı: ${boardPictureLabel()}',
                              style: const TextStyle(color: Palette.soil),
                            ),
                          ),
                          if (PhotoStore.image.value != null)
                            TextButton.icon(
                              onPressed: () async {
                                await PhotoStore.clear();
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.restart_alt_rounded, color: Palette.soilLight),
                              label: const Text('Sıfırla', style: TextStyle(color: Palette.soilLight)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _patternPicker(),
                      const SizedBox(height: 16),
                      Text('Rekor: ${Storage.best}', style: const TextStyle(color: Palette.soilLight, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _patternPicker() {
    final current = Storage.pattern;
    return Column(
      children: [
        const Text(
          'Blok deseni',
          style: TextStyle(color: Palette.soilLight, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final p in BlockPattern.values)
              Semantics(
                button: true,
                selected: p.index == current,
                label: patternNames[p],
                child: GestureDetector(
                  onTap: () => setState(() => Storage.pattern = p.index),
                  child: SizedBox(
                    width: 54,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: p.index == current ? Palette.leaf : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CustomPaint(size: const Size(40, 40), painter: _PatternSample(p)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patternNames[p]!,
                          style: TextStyle(
                            color: Palette.soil,
                            fontSize: 10.5,
                            fontWeight: p.index == current ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PatternSample extends CustomPainter {
  final BlockPattern pattern;
  _PatternSample(this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    paintSkinBlock(canvas, Offset.zero & size, pattern.index % 6, skins[0], pattern: pattern);
  }

  @override
  bool shouldRepaint(covariant _PatternSample old) => old.pattern != pattern;
}
