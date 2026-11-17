import 'dart:io';

import 'package:erp_mobile/localization/english.dart';
import 'package:erp_mobile/localization/khmer.dart';
import 'package:flutter_test/flutter_test.dart';

/// GetX keys are plain strings, so these tests catch typos and missing
/// translations.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('english.dart and khmer.dart have the same keys', () {
    expect(trEN.keys.toSet().difference(trKM.keys.toSet()), isEmpty,
        reason: 'missing in khmer.dart');
    expect(trKM.keys.toSet().difference(trEN.keys.toSet()), isEmpty,
        reason: 'missing in english.dart');
  });

  test('no empty translations', () {
    expect(trEN.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key),
        isEmpty);
    expect(trKM.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key),
        isEmpty);
  });

  test("every 'key'.tr / trParams / trPluralParams used in lib/ exists", () {
    final used = <String>{};
    final keyUse =
        RegExp(r"""'([A-Za-z0-9_]+)'\.tr(?:Params|PluralParams|Plural)?\b""");
    final pluralKey = RegExp(r"""\.trPluralParams\(\s*'([A-Za-z0-9_]+)'""");
    for (final f in dartFiles) {
      // Skip comments (they contain examples like 'key'.tr).
      final src = f.readAsLinesSync().map((l) {
        final i = l.indexOf(' //');
        return l.trimLeft().startsWith('//')
            ? ''
            : (i >= 0 ? l.substring(0, i) : l);
      }).join('\n');
      used.addAll(keyUse.allMatches(src).map((m) => m.group(1)!));
      used.addAll(pluralKey.allMatches(src).map((m) => m.group(1)!));
    }
    expect(used, isNotEmpty);
    expect(used.difference(trEN.keys.toSet()), isEmpty,
        reason: 'used in code but not in english.dart');
  });

  test('GetX is used for translations only (no GetX state, routing or widgets)',
      () {
    const allowedFull = {
      'lib/localization/language.dart',
      'lib/core/i18n/locale_cubit.dart',
    };
    final bad = <String>[];
    for (final f in dartFiles) {
      final path = f.path.replaceAll(r'\', '/');
      for (final line in f
          .readAsLinesSync()
          .where((l) => l.startsWith("import 'package:get/"))) {
        if (!allowedFull.contains(path) &&
            line != "import 'package:get/get.dart' show Trans;") {
          bad.add('$path: $line');
        }
      }
    }
    expect(bad, isEmpty,
        reason:
            "UI code may only use: import 'package:get/get.dart' show Trans;");
  });
}
