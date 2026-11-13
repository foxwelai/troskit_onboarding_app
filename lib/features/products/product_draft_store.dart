import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Disk-backed product draft helpers extracted from AddProductPage.
class ProductDraftStore {
  ProductDraftStore._();

  static String keyFor(String shopUuid) => 'product_draft_$shopUuid';

  static Future<void> save(String shopUuid, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(shopUuid), jsonEncode(data));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> load(String shopUuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(shopUuid));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
    } catch (_) {}
    return null;
  }

  static Future<void> clear(String shopUuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyFor(shopUuid));
    } catch (_) {}
  }
}
