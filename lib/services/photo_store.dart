import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's own photo used on blocks, kept small and stored locally.
class PhotoStore {
  static final image = ValueNotifier<ui.Image?>(null);
  static const _key = 'blockPhoto';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString(_key);
    if (b64 == null) return;
    try {
      image.value = await _decode(base64Decode(b64));
    } catch (_) {
      await prefs.remove(_key);
    }
  }

  /// Opens the gallery. Returns true when a photo was set.
  static Future<bool> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 85,
    );
    if (file == null) return false;
    final bytes = await file.readAsBytes();
    final img = await _decode(bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, base64Encode(bytes));
    image.value = img;
    return true;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    image.value = null;
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
    return (await codec.getNextFrame()).image;
  }
}
