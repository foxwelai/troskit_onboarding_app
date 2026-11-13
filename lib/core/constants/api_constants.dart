import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Dual API hosts + Play Store review-account routing (onboarding).
///
/// | User | Host |
/// |---|---|
/// | Email [playStoreReviewEmail] only | [devUrl] |
/// | Everyone else | [prodUrl] |
///
/// Play Console credentials:
/// email `testemp@troskit.com`, password `troskit@tester`.
///
/// Debug builds do **not** force [devUrl] — only the review email does.
class ApiConstants {
  ApiConstants._();

  /// Production onboarding API (normal employees).
  static const String prodUrl = 'https://api-prod.troskit.com';

  /// Dev / Play Store review API (Neon DB with review employee + shops).
  static const String devUrl = 'https://api-dev.testfox.in';

  /// Play Store review employee email (case-insensitive).
  static const String playStoreReviewEmail = 'testemp@troskit.com';

  /// Documented Play Console password (must match employee hash in dev DB).
  static const String playStoreReviewPassword = 'troskit@tester';

  /// Google Maps SDK + Static Maps API key.
  static const String googleMapsApiKey =
      'AIzaSyD8KbABPpupXPjJ7OKr7cLep8BmkDFYW7A';

  static const String _prefUseDevApi = 'use_development_api';

  static bool _useDevelopmentApi = false;
  static bool _initialized = false;

  /// Active API root — [devUrl] only while review-email routing is on.
  static String get baseUrl => _useDevelopmentApi ? devUrl : prodUrl;

  static bool get isUsingDevelopmentApi => _useDevelopmentApi;

  static bool get isInitialized => _initialized;

  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isPlayStoreReviewEmail(String email) =>
      normalizeEmail(email) == playStoreReviewEmail;

  /// Load persisted routing (call once at app start).
  /// Stale "use dev" without an active review session is cleared so other
  /// emails never accidentally hit [devUrl].
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final flagged = prefs.getBool(_prefUseDevApi) ?? false;
    final token = prefs.getString('employee_token');
    final rawEmployee = prefs.getString('employee_json');

    var useDev = false;
    if (flagged &&
        token != null &&
        token.isNotEmpty &&
        rawEmployee != null &&
        rawEmployee.isNotEmpty) {
      try {
        final map = jsonDecode(rawEmployee) as Map<String, dynamic>;
        final email = normalizeEmail((map['email'] ?? '').toString());
        useDev = isPlayStoreReviewEmail(email);
      } catch (_) {
        useDev = false;
      }
    }

    _useDevelopmentApi = useDev;
    await prefs.setBool(_prefUseDevApi, useDev);
    _initialized = true;
  }

  static Future<void> setUseDevelopmentApi(bool value) async {
    _useDevelopmentApi = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUseDevApi, value);
  }

  /// Route this email’s traffic before auth / API calls.
  /// Only [playStoreReviewEmail] enables [devUrl]; all others force [prodUrl].
  static Future<void> applyForEmail(String email) async {
    await setUseDevelopmentApi(isPlayStoreReviewEmail(email));
  }

  /// After logout — return to prod API.
  static Future<void> resetToLive() async {
    await setUseDevelopmentApi(false);
  }
}
