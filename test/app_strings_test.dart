// Guards lib/l10n/app_strings.dart: every English literal passed to
// context.tr(...) anywhere in lib/ must have a Bahasa Melayu entry, and
// every {placeholder} in the English text must survive into the Malay text.
// A missing entry wouldn't crash (tr() falls back to English) - it would
// just silently ship untranslated, which is what this catches.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturedu/l10n/app_strings.dart';

/// `.tr(` followed by one or more adjacent single-quoted literals.
final _trCall = RegExp(r"""\.tr\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)""");
final _literal = RegExp(r"""'((?:[^'\\]|\\.)*)'""");
final _placeholder = RegExp(r'\{(\w+)\}');

String _unescape(String raw) => raw
    .replaceAll(r"\'", "'")
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\$', r'$')
    .replaceAll(r'\\', r'\');

Set<String> _keysUsedInLib() {
  final keys = <String>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    for (final call in _trCall.allMatches(file.readAsStringSync())) {
      keys.add(
        _literal
            .allMatches(call.group(1)!)
            .map((m) => _unescape(m.group(1)!))
            .join(),
      );
    }
  }
  return keys;
}

void main() {
  final used = _keysUsedInLib();

  test('finds tr() calls at all (sanity check on the scanner)', () {
    expect(used, contains('Log In'));
    expect(used.length, greaterThan(100));
  });

  test('every tr() string has a Malay translation', () {
    final missing = used.where((k) => !malayStrings.containsKey(k)).toList()
      ..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Add these to _ms:\n${missing.join('\n')}',
    );
  });

  test('Malay text keeps every {placeholder}', () {
    for (final entry in malayStrings.entries) {
      final en = _placeholder.allMatches(entry.key).map((m) => m[1]).toSet();
      final ms = _placeholder.allMatches(entry.value).map((m) => m[1]).toSet();
      expect(ms, en, reason: entry.key);
    }
  });
}
