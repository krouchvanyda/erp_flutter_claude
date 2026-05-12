// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get appName => 'ERP Mobile';

  @override
  String get loginAppBarTitle => 'ចូលគណនី';

  @override
  String get loginButton => 'ចូល (សាកល្បង)';

  @override
  String get dashboardTitle => 'ផ្ទាំងគ្រប់គ្រង';

  @override
  String get dashboardPlaceholder =>
      'ផ្ទាំងគ្រប់គ្រងសាកល្បង — Module 2 នឹងបំពេញ។';

  @override
  String get signOutTooltip => 'ចាកចេញ';

  @override
  String get notFoundTitle => 'រកមិនឃើញ';

  @override
  String notFoundBody(String location) {
    return 'មិនមានផ្លូវសម្រាប់ \"$location\"';
  }

  @override
  String get goHome => 'ទៅទំព័រដើម';

  @override
  String get loginOtpDemoLink => '[demo] សាកល្បងលេខកូដ MFA';

  @override
  String get otpPageTitle => 'ផ្ទៀងផ្ទាត់';

  @override
  String get otpSubtitle => 'បញ្ចូលលេខកូដ ៦ ខ្ទង់ពីកម្មវិធីផ្ទៀងផ្ទាត់ឬ SMS។';

  @override
  String otpDevHint(String code) {
    return 'សាកល្បង៖ បញ្ចូល $code ដើម្បីបន្ត';
  }

  @override
  String get otpVerifyButton => 'ផ្ទៀងផ្ទាត់';

  @override
  String get otpErrorIncorrect => 'លេខកូដខុស។ សូមព្យាយាមម្ដងទៀត។';

  @override
  String get otpErrorExpired => 'លេខកូដនេះបានផុតកំណត់។ សូមស្នើសុំលេខកូដថ្មី។';

  @override
  String get otpErrorTooManyAttempts =>
      'ការព្យាយាមច្រើនពេក។ សូមព្យាយាមនៅពេលក្រោយ។';

  @override
  String get otpErrorNetwork =>
      'មិនអាចទាក់ទងម៉ាស៊ីនមេបាន។ ពិនិត្យការតភ្ជាប់របស់អ្នក។';
}
