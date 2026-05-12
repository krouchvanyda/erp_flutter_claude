// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ERP Mobile';

  @override
  String get loginAppBarTitle => 'Sign in';

  @override
  String get loginButton => 'Sign in (placeholder)';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardPlaceholder =>
      'Dashboard placeholder — Module 2 will fill this in.';

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get notFoundTitle => 'Not found';

  @override
  String notFoundBody(String location) {
    return 'No route matches \"$location\"';
  }

  @override
  String get goHome => 'Go home';

  @override
  String get loginOtpDemoLink => '[demo] Try MFA code';

  @override
  String get otpPageTitle => 'Verification';

  @override
  String get otpSubtitle =>
      'Enter the 6-digit code from your authenticator app or SMS.';

  @override
  String otpDevHint(String code) {
    return 'Demo: enter $code to continue';
  }

  @override
  String get otpVerifyButton => 'Verify';

  @override
  String get otpErrorIncorrect => 'Code is incorrect. Please try again.';

  @override
  String get otpErrorExpired => 'This code has expired. Request a new one.';

  @override
  String get otpErrorTooManyAttempts =>
      'Too many attempts. Please try again later.';

  @override
  String get otpErrorNetwork =>
      'Couldn\'t reach the server. Check your connection.';
}
