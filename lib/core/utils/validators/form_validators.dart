import 'validation_messages.dart';
import 'validators.dart';

/// Validators named after the FORM field they guard (from the MVVM template).
/// Screens use these, so a rule change for "login email" happens in one place.
abstract final class FormValidators {
  static String? loginEmail(String? value) => Validators.email(value);

  static String? loginPassword(String? value) => Validators.password(value);

  static String? registerPhone(String? value) => Validators.phone(value);

  static String? confirmPassword(String? value, String password) =>
      value != password ? ValidationMessages.passwordsDoNotMatch : null;
}
