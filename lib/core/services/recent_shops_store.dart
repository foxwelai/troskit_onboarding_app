import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks shop opens locally so Home can rank "Recently Opened" by frequency.
class RecentShopsStore {
  RecentShopsStore._();

  static const _key = 'recent_shop_opens_v1';

  /// Increment open count for [shopUuid] and refresh last-opened time.
  static Future<void> recordOpen({
    required String shopUuid,
    String? shopName,
    String? ownerName,
    String? phoneNo,
  }) async {
    if (shopUuid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = await _read(prefs);
      final existing = Map<String, dynamic>.from(
        (map[shopUuid] as Map?) ?? const {},
      );
      final count = (existing['count'] as num?)?.toInt() ?? 0;
      map[shopUuid] = {
        'count': count + 1,
        'last_opened_ms': DateTime.now().millisecondsSinceEpoch,
        if (shopName != null && shopName.isNotEmpty) 'shop_name': shopName,
        if (ownerName != null && ownerName.isNotEmpty) 'owner_name': ownerName,
        if (phoneNo != null && phoneNo.isNotEmpty) 'phone_no': phoneNo,
        // Keep prior snapshot fields when new ones aren't provided.
        if (shopName == null && existing['shop_name'] != null)
          'shop_name': existing['shop_name'],
        if (ownerName == null && existing['owner_name'] != null)
          'owner_name': existing['owner_name'],
        if (phoneNo == null && existing['phone_no'] != null)
          'phone_no': existing['phone_no'],
      };
      await prefs.setString(_key, jsonEncode(map));
    } catch (_) {}
  }

  /// Top shops by open frequency (then most recent). Max [limit].
  static Future<List<Map<String, dynamic>>> top({int limit = 5}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = await _read(prefs);
      final entries = map.entries.map((e) {
        final v = Map<String, dynamic>.from(e.value as Map? ?? const {});
        return {
          'uuid': e.key,
          'count': (v['count'] as num?)?.toInt() ?? 0,
          'last_opened_ms': (v['last_opened_ms'] as num?)?.toInt() ?? 0,
          'shop_name': v['shop_name'],
          'owner_name': v['owner_name'],
          'phone_no': v['phone_no'],
        };
      }).toList();

      entries.sort((a, b) {
        final byCount = (b['count'] as int).compareTo(a['count'] as int);
        if (byCount != 0) return byCount;
        return (b['last_opened_ms'] as int)
            .compareTo(a['last_opened_ms'] as int);
      });

      return entries.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }
}
