import 'dart:io';

import 'package:blazegrid/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every translated string has English text', () {
    final missing = <String>[];
    final call = RegExp(r"""tx\('((?:[^'\\]|\\.)*)'\)|tx\("([^"]*)"\)""");
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        final key = (m.group(1) ?? m.group(2))!.replaceAll(r"\'", "'");
        if (!en.containsKey(key)) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty);
  });

  test('names shown through tx have English text', () {
    final src = [
      File('lib/ui/scenes.dart').readAsStringSync(),
      File('lib/ui/skins.dart').readAsStringSync(),
      File('lib/game/game_state.dart').readAsStringSync(),
    ].join();
    for (final block in [
      RegExp(r'const sceneNames = <String>\[(.*?)\];', dotAll: true),
      RegExp(r'const patternNames = <BlockPattern, String>\{(.*?)\};', dotAll: true),
      RegExp(r'const goalText = <Goal, String>\{(.*?)\};', dotAll: true),
    ]) {
      final body = block.firstMatch(src)!.group(1)!;
      for (final m in RegExp("'([^']+)'|\"([^\"]+)\"").allMatches(body)) {
        final key = m.group(1) ?? m.group(2)!;
        expect(en.containsKey(key), isTrue, reason: key);
      }
    }
  });
}
