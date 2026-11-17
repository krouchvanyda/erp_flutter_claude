import 'dart:ui';

import 'package:erp_mobile/core/i18n/locale_cubit.dart';
import 'package:erp_mobile/localization/language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleCubit.resolve', () {
    test('saved language wins over the device language', () {
      expect(LocaleCubit.resolve('km', const [Locale('en', 'US')]),
          Language.khmer);
    });

    test('falls back to the first supported device language', () {
      expect(
        LocaleCubit.resolve(null, const [Locale('fr'), Locale('km')]),
        Language.khmer,
      );
    });

    test('falls back to English when nothing matches', () {
      expect(LocaleCubit.resolve(null, const [Locale('fr')]),
          Language.english);
    });
  });

  group('LocaleCubit.changeLanguage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await Language.init(Language.english);
    });

    test('saves the choice, switches GetX text and emits the new locale',
        () async {
      final cubit = LocaleCubit(prefs, deviceLocales: const [Locale('en')]);
      expect(cubit.state, Language.english);
      expect('chatInboxTitle'.tr, 'Messages');

      await cubit.changeLanguage('km');

      expect(cubit.state, Language.khmer);
      expect(prefs.getString(LocaleCubit.storageKey), 'km');
      expect('chatInboxTitle'.tr, 'សារ');
      await cubit.close();
    });

    test('a saved language is restored on the next start', () async {
      await prefs.setString(LocaleCubit.storageKey, 'km');
      final cubit = LocaleCubit(prefs, deviceLocales: const [Locale('en')]);
      expect(cubit.state, Language.khmer);
      await cubit.close();
    });

    test('ignores unsupported codes', () async {
      final cubit = LocaleCubit(prefs, deviceLocales: const [Locale('en')]);
      await cubit.changeLanguage('fr');
      expect(cubit.state, Language.english);
      expect(prefs.getString(LocaleCubit.storageKey), isNull);
      await cubit.close();
    });
  });
}
