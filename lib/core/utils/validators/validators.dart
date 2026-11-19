import 'validation_messages.dart';

/// Small, reusable checks (from the MVVM template).
/// Each returns `null` when OK, or the error text to show under the field —
/// exactly what `TextFormField(validator: ...)` expects.
abstract final class Validators {
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationMessages.required;
    }
    return null;
  }

  static String? email(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim());
    return ok ? null : ValidationMessages.emailInvalid;
  }

  /// Backend rule (API_LIST_BACKEND.md): password 6–100 characters.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return ValidationMessages.required;
    if (value.length < 6) return ValidationMessages.passwordShort;
    return null;
  }

  static String? phone(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    final ok = RegExp(r'^\+?[0-9]{8,15}$').hasMatch(value!.trim());
    return ok ? null : ValidationMessages.phoneInvalid;
  }
}
