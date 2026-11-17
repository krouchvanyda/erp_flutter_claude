import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'english.dart';
import 'khmer.dart';

/// GetX translations (GetX is used for translations only; no GetX state,
/// routing or widgets in the app — BLoC owns all state).
///
/// Use text as `'key'.tr`, `'key'.trParams({'name': x})`,
/// `'key'.trPluralParams('keyPlural', n, {'count': '$n'})`.
class Language extends Translations {
  static const english = Locale('en', 'US');

  /// `km` = ISO code for Khmer (`kh` is a common mistake and never matches).
  static const khmer = Locale('km', 'KH');

  static const supportedLocales = [english, khmer];

  @override
  Map<String, Map<String, String>> get keys => {'en_US': trEN, 'km_KH': trKM};

  /// Call once before `runApp`. Also loads date names (ចន្ទ, មករា…) for
  /// `DateFormat`.
  static Future<void> init(Locale locale) async {
    Get.clearTranslations();
    Get.addTranslations(Language().keys);
    Get.fallbackLocale = english;
    await initializeDateFormatting();
    apply(locale);
  }

  /// Switches GetX text AND `DateFormat` (month/day names) to [locale].
  static void apply(Locale locale) {
    Get.locale = locale;
    Intl.defaultLocale = locale.languageCode;
  }

  /// `en` / `km` for `DateFormat`.
  static String get languageCode =>
      Get.locale?.languageCode ?? english.languageCode;
}
