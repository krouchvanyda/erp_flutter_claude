import 'dart:io';

/// "Is the PHONE online?" (from the MVVM template).
///
/// Used only AFTER a request failed to connect, to tell the user the right
/// thing: "check your internet" (phone offline) vs "server unreachable"
/// (phone online, our server down / wrong IP).
abstract final class CheckInternetService {
  static Future<bool> checkDataConnection() async {
    try {
      // A DNS lookup needs the internet but no extra package and no full
      // HTTP request (the template fetched https://www.google.com).
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false; // no DNS answer → offline
    }
  }
}
