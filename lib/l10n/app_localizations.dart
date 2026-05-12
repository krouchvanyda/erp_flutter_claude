import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// Application title shown on splash and home screens
  ///
  /// In en, this message translates to:
  /// **'ERP Mobile'**
  String get appName;

  /// Title bar on the login screen
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginAppBarTitle;

  /// Primary button on the login form. Placeholder copy until Module 1 ships the real OAuth flow.
  ///
  /// In en, this message translates to:
  /// **'Sign in (placeholder)'**
  String get loginButton;

  /// Title bar on the dashboard / home screen
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// Body text on the dashboard while Module 2 is unimplemented
  ///
  /// In en, this message translates to:
  /// **'Dashboard placeholder — Module 2 will fill this in.'**
  String get dashboardPlaceholder;

  /// Tooltip on the sign-out icon button in the dashboard app bar
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutTooltip;

  /// Title bar on the 404 / no-route-matched page
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFoundTitle;

  /// Body text on the 404 page; explains which path the router could not resolve
  ///
  /// In en, this message translates to:
  /// **'No route matches \"{location}\"'**
  String notFoundBody(String location);

  /// Action button that returns the user to the splash / home route
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHome;

  /// Subtle text button on the login page that navigates to the OTP demo route (Slice 1.2.1)
  ///
  /// In en, this message translates to:
  /// **'[demo] Try MFA code'**
  String get loginOtpDemoLink;

  /// Title bar on the OTP / TOTP entry page
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get otpPageTitle;

  /// Body copy under the OTP page icon, instructing the user
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app or SMS.'**
  String get otpSubtitle;

  /// Italic hint reminding the user of the dev backdoor code while the real verifier is not wired
  ///
  /// In en, this message translates to:
  /// **'Demo: enter {code} to continue'**
  String otpDevHint(String code);

  /// Primary action button on the OTP page
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerifyButton;

  /// Error shown under the OTP boxes when the entered code does not match
  ///
  /// In en, this message translates to:
  /// **'Code is incorrect. Please try again.'**
  String get otpErrorIncorrect;

  /// Error shown when the OTP validity window has elapsed
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Request a new one.'**
  String get otpErrorExpired;

  /// Error shown when the server throttles further OTP attempts
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get otpErrorTooManyAttempts;

  /// Error shown when the OTP verifier is unreachable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection.'**
  String get otpErrorNetwork;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
