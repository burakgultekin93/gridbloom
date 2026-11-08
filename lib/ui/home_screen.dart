import 'package:flutter/material.dart';

import '../services/storage.dart';
import 'game_screen.dart';
import 'painters.dart';
import 'palette.dart';

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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ayarlar', style: TextStyle(color: Palette.soil, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            SwitchListTile(
              title: const Text('Titreşim'),
              value: Storage.haptics,
              activeThumbColor: Palette.leaf,
              onChanged: (v) => set(() => Storage.haptics = v),
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
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSave = Storage.hasSavedGame;
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 120, height: 120, child: CustomPaint(painter: LogoPainter())),
                const SizedBox(height: 20),
                const Text('Gridbloom',
                    style: TextStyle(color: Palette.soil, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const Text('Blokları yerleştir, bahçeyi çiçeklendir',
                    textAlign: TextAlign.center, style: TextStyle(color: Palette.soilLight, fontSize: 16)),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Palette.leaf, padding: const EdgeInsets.all(18)),
                    onPressed: () => _open(resume: hasSave),
                    child: Text(hasSave ? 'Devam et' : 'Oyna', style: const TextStyle(fontSize: 20)),
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
                const SizedBox(height: 24),
                Text('Rekor: ${Storage.best}', style: const TextStyle(color: Palette.soilLight, fontSize: 16)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
