import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/language.dart';

/// App language (BLoC). State = the language shown now (`en_US` or `km_KH`).
///
/// The single owner of the language choice: saves it in SharedPreferences
/// (so it survives restarts) and sets the GetX translation language.
/// [LocaleRebuilder] (above MaterialApp) then redraws every screen.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._prefs, {List<Locale>? deviceLocales})
      : super(resolve(
          _saved(_prefs),
          deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales,
        ));

  final SharedPreferences _prefs;

  static const storageKey = 'app_language';
  static const supportedCodes = ['en', 'km'];

  static String? _saved(SharedPreferences prefs) {
    final code = prefs.getString(storageKey);
    return supportedCodes.contains(code) ? code : null;
  }

  Future<void> changeLanguage(String code) async {
    if (!supportedCodes.contains(code) || state.languageCode == code) return;
    final locale = localeFor(code);
    await _prefs.setString(storageKey, code);
    // `'key'.tr` and DateFormat now use the new language.
    Language.apply(locale);
    emit(locale); // LocaleRebuilder redraws the screens
  }

  static Locale localeFor(String code) =>
      code == 'km' ? Language.khmer : Language.english;

  /// The language to show: the saved one, else the phone's one if we
  /// support it, else English.
  static Locale resolve(String? savedCode, List<Locale> deviceLocales) {
    if (savedCode != null) return localeFor(savedCode);
    for (final l in deviceLocales) {
      if (supportedCodes.contains(l.languageCode)) {
        return localeFor(l.languageCode);
      }
    }
    return Language.english;
  }

  /// Start-up language, before the cubit exists (used by `main`).
  static Locale initial(SharedPreferences prefs) => resolve(
        _saved(prefs),
        WidgetsBinding.instance.platformDispatcher.locales,
      );
}
