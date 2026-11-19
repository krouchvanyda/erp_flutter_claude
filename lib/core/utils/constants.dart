/// Fixed texts and codes used by the network layer (from the MVVM template).
///
/// All in ONE place so Step 8 can turn them into translation keys easily.
abstract final class Constants {
  // ── Status codes we invent (real HTTP codes are 100–599) ──
  static const int codeUnknown = 0;
  static const int codeNetwork = -1;

  // ── Titles / descriptions ──
  static const String unKnownError = 'Error';
  static const String error = 'Error';
  static const String somethingWentWrong = 'Something went wrong.';
  static const String noInternet = 'No Internet';
  static const String pleaseCheckInternet = 'Please check internet connection.';
  static const String serverUnreachable = 'Server unreachable';
  static const String pleaseTryLater =
      'Cannot reach the server. Please try again later.';
  static const String timeout = 'Timeout';
  static const String serverTooSlow = 'The server is taking too long.';
  static const String sessionExpired = 'Session expired';
  static const String pleaseLoginAgain = 'Please sign in again.';
  static const String serverError = 'Server error';
}
