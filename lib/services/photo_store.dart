import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/scenes.dart';

/// The picture spread across the board: none, a ready-made scene, or the
/// player's own photo. Kept locally on the phone.
class PhotoStore {
  static final image = ValueNotifier<ui.Image?>(null);

  /// Index of the ready-made scene in use, or null.
  static int? scene;
  static bool get isGallery => image.value != null && scene == null;

  static const _photoKey = 'blockPhoto';
  static const _sceneKey = 'boardScene';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final sc = prefs.getInt(_sceneKey);
    if (sc != null && sc >= 0 && sc < sceneCount) {
      scene = sc;
      image.value = await renderScene(sc);
      return;
    }
    final b64 = prefs.getString(_photoKey);
    if (b64 == null) return;
    try {
      image.value = await _decode(base64Decode(b64));
    } catch (_) {
      await prefs.remove(_photoKey);
    }
  }

  /// Opens the gallery. Returns true when a photo was set.
  static Future<bool> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return false;
    final bytes = await file.readAsBytes();
    final img = await _decode(bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoKey, base64Encode(bytes));
    await prefs.remove(_sceneKey);
    scene = null;
    image.value = img;
    return true;
  }

  static Future<void> useScene(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sceneKey, index);
    scene = index;
    image.value = await renderScene(index);
  }

  /// Back to plain coloured blocks.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_photoKey);
    await prefs.remove(_sceneKey);
    scene = null;
    image.value = null;
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 768);
    return (await codec.getNextFrame()).image;
  }
}
