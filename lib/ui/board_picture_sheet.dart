import 'package:flutter/material.dart';

import '../l10n.dart';

import '../services/photo_store.dart';
import 'palette.dart';
import 'scenes.dart';

/// Lets the player pick a ready-made board picture, use their own photo,
/// or reset back to plain coloured blocks.
Future<void> showBoardPictureSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => const _BoardPictureSheet(),
  );
}

/// Short label for what the board shows now.
String boardPictureLabel() {
  if (PhotoStore.scene != null) return tx(sceneNames[PhotoStore.scene!]);
  if (PhotoStore.image.value != null) return tx('Kendi fotoğrafın');
  return tx('Yok');
}

class _BoardPictureSheet extends StatefulWidget {
  const _BoardPictureSheet();

  @override
  State<_BoardPictureSheet> createState() => _BoardPictureSheetState();
}

class _BoardPictureSheetState extends State<_BoardPictureSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tx('Fotoğraf açılamadı. Başka bir fotoğraf dene.'))));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasPicture = PhotoStore.image.value != null;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tx('Tahta fotoğrafı'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.soil, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                tx('Bloklar yerleştikçe resim tahtada ortaya çıkar.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.soilLight, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.leaf,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final ok = await PhotoStore.pick();
                              if (ok && context.mounted) Navigator.pop(context);
                            }),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(tx('Galeriden seç')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Palette.soil, padding: const EdgeInsets.all(14)),
                      onPressed: _busy || !hasPicture ? null : () => _run(PhotoStore.clear),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: Text(tx('Sıfırla')),
                    ),
                  ),
                ],
              ),
              if (PhotoStore.isGallery) ...[
                const SizedBox(height: 8),
                Text(
                  tx('Şu an kendi fotoğrafın kullanılıyor.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.soilLight, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                tx('Hazır resimler'),
                style: TextStyle(color: Palette.soil, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: [for (var i = 0; i < sceneCount; i++) _sceneTile(i)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sceneTile(int i) {
    final selected = PhotoStore.scene == i;
    return Semantics(
      button: true,
      selected: selected,
      label: tx(sceneNames[i]),
      child: GestureDetector(
        onTap: _busy
            ? null
            : () => _run(() async {
                await PhotoStore.useScene(i);
                if (mounted) Navigator.pop(context);
              }),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? Palette.leaf : Colors.transparent, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CustomPaint(painter: ScenePainter(i)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tx(sceneNames[i]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Palette.soil,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
