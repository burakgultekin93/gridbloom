import 'package:flutter/material.dart';

import '../l10n.dart';

import '../services/photo_store.dart';
import '../services/sound.dart';
import '../services/storage.dart';
import 'game_screen.dart';
import 'painters.dart';
import 'board_picture_sheet.dart';
import 'palette.dart';
import 'privacy_screen.dart';
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
      backgroundColor: Palette.panel,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tx('Ayarlar'),
                      style: const TextStyle(color: Palette.soil, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(tx('Ses efektleri')),
                    value: Storage.sound,
                    activeThumbColor: Palette.leaf,
                    onChanged: (v) => set(() => Storage.sound = v),
                  ),
                  if (Storage.sound)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(tx('Ses paketi'), style: TextStyle(color: Palette.soilLight)),
                          for (var i = 0; i < Sound.packs.length; i++)
                            Padding(
                              padding: EdgeInsets.zero,
                              child: ChoiceChip(
                                label: Text(tx(Sound.packs[i].$2)),
                                selected: Sound.pack == i,
                                selectedColor: Palette.leaf,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: Sound.pack == i ? Colors.white : Palette.soil,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) {
                                  final done = Sound.setPack(i);
                                  set(() {});
                                  done.then((_) => set(() {}));
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  SwitchListTile(
                    title: Text(tx('Müzik')),
                    value: Storage.music,
                    activeThumbColor: Palette.leaf,
                    onChanged: (v) {
                      set(() => Storage.music = v);
                      Sound.applyMusicSetting();
                    },
                  ),
                  SwitchListTile(
                    title: Text(tx('Titreşim')),
                    value: Storage.haptics,
                    activeThumbColor: Palette.leaf,
                    onChanged: (v) => set(() => Storage.haptics = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(tx('Dil'), style: const TextStyle(color: Palette.soilLight)),
                        for (var i = 0; i < Lang.options.length; i++)
                          ChoiceChip(
                            label: Text(tx(Lang.options[i])),
                            selected: Storage.language == i,
                            selectedColor: Palette.leaf,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: Storage.language == i ? Colors.white : Palette.soil,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) {
                              Storage.language = i;
                              set(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.wallpaper_rounded, color: Palette.leaf),
                    title: Text(tx('Tahta fotoğrafı')),
                    subtitle: Text(boardPictureLabel()),
                    onTap: () async {
                      await showBoardPictureSheet(context);
                      set(() {});
                      if (mounted) setState(() {});
                    },
                  ),
                  ListTile(
                    title: Text(tx('Öğreticiyi tekrar göster')),
                    onTap: () {
                      Storage.tutorialSeen = false;
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    title: Text(tx('Gizlilik politikası')),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                    },
                  ),
                  ListTile(title: Text(tx('Destek')), subtitle: Text('avburakgultekin@icloud.com')),
                  const SizedBox(height: 8),
                ],
              ),
            ),
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
            colors: [Color(0xFF123A5E), Color(0xFF0D1120), Color(0xFF3A1210)],
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
                  tooltip: tx('Ayarlar'),
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
                          colors: [Color(0xFF7FD3FF), Color(0xFFA98BFF), Color(0xFFFF8A3D), Color(0xFFFF4A2A)],
                        ).createShader(r),
                        child: Text(
                          'Blazegrid',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      Text(
                        tx('Buzdan başla, seriyle alevlen'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Palette.soilLight, fontSize: 16),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.leaf,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(18),
                          ),
                          onPressed: () => _open(resume: hasSave),
                          child: Text(
                            hasSave ? tx('Klasik mod · Devam et') : tx('Klasik mod'),
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
                          child: Text(tx('Yeni oyun'), style: TextStyle(color: Palette.soil)),
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
                              '${tx('Tahta fotoğrafı')}: ${boardPictureLabel()}',
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
                              label: Text(tx('Sıfırla'), style: TextStyle(color: Palette.soilLight)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _patternPicker(),
                      const SizedBox(height: 16),
                      Text(
                        '${tx('Rekor')}: ${Storage.best}',
                        style: const TextStyle(color: Palette.soilLight, fontSize: 16),
                      ),
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
        Text(
          tx('Blok deseni'),
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
                label: tx(patternNames[p]!),
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
                          tx(patternNames[p]!),
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
