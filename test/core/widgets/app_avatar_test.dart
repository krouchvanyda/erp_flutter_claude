import 'package:erp_mobile/core/widgets/app_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initials: up to 2 words, upper case, safe for empty', () {
    expect(AppAvatar.initialsOf('Jane Doe'), 'JD');
    expect(AppAvatar.initialsOf('  jane   mary doe '), 'JM');
    expect(AppAvatar.initialsOf('vanyda'), 'V');
    expect(AppAvatar.initialsOf(''), '?');
    // .characters = what a PERSON sees as one letter: the Khmer vowel sign
    // stays on its consonant (សុ, ចា), never a broken floating mark.
    expect(AppAvatar.initialsOf('សុខ ចាន់'), 'សុចា');
  });
}
