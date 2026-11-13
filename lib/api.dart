import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/api_constants.dart';
import 'core/services/maintenance_service.dart';

class AccessBlockedException implements Exception {

  final String message;
  AccessBlockedException([this.message = 'Your onboarding access has been disabled by Troskit admin.']);

  @override
  String toString() => message;
}

class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();

  bool isExpired(Duration ttl) => DateTime.now().difference(timestamp) > ttl;
}

class OnboardingApi {
  /// Shared client — reuses TCP/TLS connections across API calls.
  static final http.Client _client = http.Client();

  static _CacheEntry<List<dynamic>>? _categoriesCache;
  static _CacheEntry<List<dynamic>>? _shopsCache;
  static final Map<String, _CacheEntry<Map<String, dynamic>>> _shopDetailsCache = {};
  static final Map<String, _CacheEntry<List<dynamic>>> _productsCache = {};
  static _CacheEntry<Map<String, dynamic>>? _meCache;

  static const _ttlMemory = Duration(minutes: 5);
  static const _ttlDisk = Duration(hours: 12);
  static const _ttlMe = Duration(minutes: 2);

  static const _cacheKeyCategories = 'disk_cache_categories_v1';
  static const _cacheKeyShops = 'disk_cache_shops_v1';
  static const _cacheKeyShopPrefix = 'disk_cache_shop_';
  static const _cacheKeyProductsPrefix = 'disk_cache_products_';

  static Future<void> _writeDisk(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode({
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }));
    } catch (_) {}
  }

  static Future<dynamic> _readDisk(String key, {Duration? ttl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (ttl != null) {
        final ts = decoded['ts'];
        if (ts is int) {
          final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
          if (age > ttl) return null;
        }
      }
      return decoded['data'];
    } catch (_) {
      return null;
    }
  }

  static Future<void> _removeDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  static void clearCache({
    bool categories = true,
    bool shops = true,
    String? shopUuid,
  }) {
    if (categories) {
      _categoriesCache = null;
      _removeDisk(_cacheKeyCategories);
    }
    if (shops) {
      _shopsCache = null;
      _upcomingCache = null;
      _shopDetailsCache.clear();
      _removeDisk(_cacheKeyShops);
      _removeDisk(_cacheKeyUpcoming);
    }
    if (shopUuid != null) {
      _productsCache.remove(shopUuid);
      _shopDetailsCache.remove(shopUuid);
      _removeDisk('$_cacheKeyProductsPrefix$shopUuid');
      _removeDisk('$_cacheKeyShopPrefix$shopUuid');
    } else {
      _productsCache.clear();
      _meCache = null;
      _activityCache = null;
      // Sweep all per-shop / per-product disk keys on full clear (logout).
      unawaited(_clearAllProductDiskKeys());
    }
  }

  static Future<void> _clearAllProductDiskKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
          k.startsWith(_cacheKeyProductsPrefix) ||
          k.startsWith(_cacheKeyShopPrefix) ||
          k.startsWith('disk_cache_product_'));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  static String? _cachedToken;
  static Map<String, dynamic>? _cachedEmployee;

  static Map<String, dynamic>? get cachedEmployee => _cachedEmployee;
  static String? get cachedToken => _cachedToken;

  static Future<String?> _token() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('employee_token');
    return _cachedToken;
  }

  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> employee,
  }) async {
    _cachedToken = token;
    _cachedEmployee = employee;
    MaintenanceService.instance.startMonitoring();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employee_token', token);
    await prefs.setString('employee_json', jsonEncode(employee));
  }

  static Future<Map<String, dynamic>?> currentEmployee() async {
    if (_cachedEmployee != null) return _cachedEmployee;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('employee_json');
    if (raw == null) return null;
    try {
      _cachedEmployee = jsonDecode(raw) as Map<String, dynamic>;
      return _cachedEmployee;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    clearCache();
    _cachedToken = null;
    _cachedEmployee = null;
    MaintenanceService.instance.stopMonitoring();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('employee_token');
    await prefs.remove('employee_json');
    await ApiConstants.resetToLive();
  }

  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await _token();
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      // ngrok free interstitial / browser warning bypass for API clients
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Converts raw exceptions, network errors, and technical strings into friendly, human-readable user messages.
  /// Completely hides raw endpoints, HTTP status codes, stack traces, and internal API URLs.
  static String toUserMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    if (error is AccessBlockedException) {
      return error.message;
    }

    final raw = error.toString().replaceFirst('Exception: ', '').trim();

    // Check for network connection failures
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('ClientException') ||
        raw.contains('No address associated with hostname') ||
        raw.contains('Connection refused') ||
        raw.contains('Network is unreachable')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }

    // Check for timeouts & gateway errors
    if (raw.contains('TimeoutException') ||
        raw.contains('Timeout') ||
        raw.contains('502') ||
        raw.contains('503') ||
        raw.contains('504') ||
        raw.toLowerCase().contains('gateway timeout')) {
      return 'The server is taking longer than expected to respond. Please try again.';
    }

    // Check for authorization / access blocked
    if (raw.contains('401') ||
        raw.contains('403') ||
        raw.toLowerCase().contains('unauthorized') ||
        raw.toLowerCase().contains('access blocked') ||
        raw.toLowerCase().contains('access removed')) {
      return 'Access restricted: You are not authorized for this action.';
    }

    // Check for 404 / Not Found
    if (raw.contains('404') || raw.toLowerCase().contains('not found')) {
      return 'The requested store or product details could not be found.';
    }

    // Check for 500 / Server Error
    if (raw.contains('500') || raw.toLowerCase().contains('internal server error')) {
      return 'Something went wrong on our servers. Please try again in a moment.';
    }

    // If message contains URLs, endpoints, ngrok, localhost, stack traces, or technical symbols:
    if (raw.contains('http://') ||
        raw.contains('https://') ||
        raw.contains('baseUrl') ||
        raw.contains('ngrok') ||
        raw.contains('10.0.2.2') ||
        raw.contains('/onboarding/') ||
        raw.contains('FormatError') ||
        raw.contains('TypeError') ||
        raw.contains('NoSuchMethodError')) {
      return 'Unable to complete action right now. Please try again.';
    }

    return raw;
  }

  static Future<dynamic> _parseOrThrow(http.Response res, String defaultError) async {
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      final msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Access removed: Not Authorized by Troskit admin.';
      throw AccessBlockedException(msg);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : (res.statusCode == 502 || res.statusCode == 503 || res.statusCode == 504
              ? 'The server is taking longer than expected to respond. Please try again.'
              : defaultError);
      throw Exception(msg);
    }
    return body;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final isReview = ApiConstants.isPlayStoreReviewEmail(normalized);
    // Non-review → always prodUrl; review → always devUrl (even in debug).
    await ApiConstants.applyForEmail(normalized);

    try {
      final res = await _client
          .post(
            Uri.parse('${ApiConstants.baseUrl}/onboarding/auth/login'),
            headers: ApiConstants.defaultHeaders,
            body: jsonEncode({'email': normalized, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) {
        if (!isReview) await ApiConstants.resetToLive();
        throw Exception(body['message'] ?? 'Login failed');
      }
      await saveSession(
        token: body['token'] as String,
        employee: Map<String, dynamic>.from(body['employee'] as Map),
      );
      await ApiConstants.applyForEmail(
        (body['employee']?['email'] ?? normalized).toString(),
      );
      return body;
    } catch (e) {
      if (!isReview) await ApiConstants.resetToLive();
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> me({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _meCache != null &&
        !_meCache!.isExpired(_ttlMe)) {
      return Map<String, dynamic>.from(_meCache!.data);
    }
    final res = await _client
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/me'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 12));
    final body = await _parseOrThrow(res, 'Failed to load profile');
    final map = Map<String, dynamic>.from(body as Map);
    if (map['is_active'] == false) {
      throw AccessBlockedException('Your onboarding access has been disabled by Troskit admin.');
    }
    await saveSession(
      token: (await _token()) ?? '',
      employee: map,
    );
    _meCache = _CacheEntry(map);
    return map;
  }

  static void _checkMaintenanceIfRefresh(bool forceRefresh) {
    if (forceRefresh) {
      MaintenanceService.instance.checkStatus().catchError((_) => MaintenanceService.instance.status);
    }
  }

  static Future<List<dynamic>> listCategories({bool forceRefresh = false}) async {
    _checkMaintenanceIfRefresh(forceRefresh);
    if (!forceRefresh) {
      if (_categoriesCache != null && !_categoriesCache!.isExpired(_ttlMemory)) {
        return _categoriesCache!.data;
      }
      final disk = await _readDisk(_cacheKeyCategories, ttl: const Duration(days: 2));
      if (disk is List) {
        _categoriesCache = _CacheEntry(List<dynamic>.from(disk));
        return _categoriesCache!.data;
      }
    }

    final res = await _client
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/categories'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load categories');
    final list = body is List
        ? body
        : (body is Map && body['categories'] is List
            ? body['categories'] as List
            : null);
    if (list == null) {
      throw Exception('Unexpected categories response from server');
    }
    final casted = List<dynamic>.from(list);
    _categoriesCache = _CacheEntry(casted);
    _writeDisk(_cacheKeyCategories, casted);
    return casted;
  }

  static Future<Map<String, dynamic>> createCategory({
    required String categoryName,
    String? description,
  }) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/categories'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'category_name': categoryName,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to create category');
    _categoriesCache = null;
    if (body is! Map) {
      throw Exception('Unexpected create-category response from server');
    }
    // Nest may wrap as { category: {...} } or return the row directly.
    final row = body['category'] is Map
        ? Map<String, dynamic>.from(body['category'] as Map)
        : Map<String, dynamic>.from(body);
    return row;
  }

  static Future<List<dynamic>> listShops({bool forceRefresh = false}) async {
    _checkMaintenanceIfRefresh(forceRefresh);
    if (!forceRefresh) {
      if (_shopsCache != null && !_shopsCache!.isExpired(_ttlMemory)) {
        return _shopsCache!.data;
      }
      final disk = await _readDisk(_cacheKeyShops, ttl: _ttlDisk);
      if (disk is List) {
        final list = List<dynamic>.from(disk);
        _shopsCache = _CacheEntry(list);
        return list;
      }
    }
    final res = await _client
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/shops'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load shops');
    final list = List<dynamic>.from(body as List);
    _shopsCache = _CacheEntry(list);
    _writeDisk(_cacheKeyShops, list);
    return list;
  }

  static _CacheEntry<List<dynamic>>? _upcomingCache;
  static const _cacheKeyUpcoming = 'upcoming_onboardings_v1';

  /// Enquiry-assigned shops that still need onboarding (pending verification).
  static Future<List<dynamic>> listUpcomingOnboardings({
    bool forceRefresh = false,
  }) async {
    _checkMaintenanceIfRefresh(forceRefresh);
    const ttl = Duration(minutes: 2);
    if (!forceRefresh) {
      if (_upcomingCache != null && !_upcomingCache!.isExpired(ttl)) {
        return _upcomingCache!.data;
      }
      final disk = await _readDisk(_cacheKeyUpcoming, ttl: ttl);
      if (disk is List) {
        final list = List<dynamic>.from(disk);
        _upcomingCache = _CacheEntry(list);
        return list;
      }
    }
    final res = await _client
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/upcoming-onboardings'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load upcoming onboardings');
    final list = List<dynamic>.from(body as List);
    _upcomingCache = _CacheEntry(list);
    _writeDisk(_cacheKeyUpcoming, list);
    return list;
  }

  static _CacheEntry<List<dynamic>>? _activityCache;

  static Future<List<dynamic>> listActivityFeed({bool forceRefresh = false}) async {
    _checkMaintenanceIfRefresh(forceRefresh);
    const ttl = Duration(minutes: 2);
    if (!forceRefresh && _activityCache != null && !_activityCache!.isExpired(ttl)) {
      return _activityCache!.data;
    }
    final res = await _client
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/activity'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load activity');
    final list = body as List<dynamic>;
    _activityCache = _CacheEntry(list);
    return list;
  }

  static Future<Map<String, dynamic>> getShop(String shopUuid, {bool forceRefresh = false}) async {
    _checkMaintenanceIfRefresh(forceRefresh);
    final diskKey = '$_cacheKeyShopPrefix$shopUuid';
    if (!forceRefresh) {
      final cached = _shopDetailsCache[shopUuid];
      if (cached != null && !cached.isExpired(_ttlMemory)) {
        return cached.data;
      }
      final disk = await _readDisk(diskKey, ttl: _ttlDisk);
      if (disk is Map) {
        final map = Map<String, dynamic>.from(disk);
        _shopDetailsCache[shopUuid] = _CacheEntry(map);
        return map;
      }
    }
    final res = await _client
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/shops/$shopUuid'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load shop');
    final map = Map<String, dynamic>.from(body as Map);
    _shopDetailsCache[shopUuid] = _CacheEntry(map);
    _writeDisk(diskKey, map);
    return map;
  }

  static Future<Map<String, dynamic>> requestEcom({
    required String shopUuid,
    double? latitude,
    double? longitude,
    bool enabled = true,
  }) async {
    final res = await _client
        .post(
          Uri.parse(
            '${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/ecom/request',
          ),
          headers: await _authHeaders(),
          body: jsonEncode({
            'enabled': enabled,
            'latitude': ?latitude,
            'longitude': ?longitude,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to request ECOM');
    _shopDetailsCache.remove(shopUuid);
    _shopsCache = null;
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Map<String, dynamic>> createShop(Map<String, dynamic> payload) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/shops'),
          headers: await _authHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));
    final body = await _parseOrThrow(res, 'Failed to create shop');
    _shopsCache = null;
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<List<dynamic>> listProducts(String shopUuid, {bool forceRefresh = false}) async {
    _checkMaintenanceIfRefresh(forceRefresh);
    final diskKey = '$_cacheKeyProductsPrefix$shopUuid';
    if (!forceRefresh) {
      final cached = _productsCache[shopUuid];
      if (cached != null && !cached.isExpired(_ttlMemory)) {
        return cached.data;
      }
      final disk = await _readDisk(diskKey, ttl: _ttlDisk);
      if (disk is List) {
        final list = List<dynamic>.from(disk);
        _productsCache[shopUuid] = _CacheEntry(list);
        return list;
      }
    }

    final res = await _client
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/products'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load products');
    final list = List<dynamic>.from(body as List);
    _productsCache[shopUuid] = _CacheEntry(list);
    _writeDisk(diskKey, list);
    return list;
  }

  /// Scan helper: shop Product first, else Troskit master catalog autofill.
  static Future<Map<String, dynamic>> lookupCatalog({
    required String shopUuid,
    required String barcode,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/catalog/lookup',
    ).replace(queryParameters: {'barcode': barcode});
    final res = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Catalog lookup failed');
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Map<String, dynamic>> getProduct({
    required String shopUuid,
    required String productUuid,
    bool forceRefresh = false,
  }) async {
    final diskKey = 'disk_cache_product_${shopUuid}_$productUuid';
    if (!forceRefresh) {
      final list = _productsCache[shopUuid]?.data;
      if (list != null) {
        final match = list.cast<dynamic>().firstWhere(
          (p) => (p is Map && p['uuid']?.toString() == productUuid),
          orElse: () => null,
        );
        if (match is Map) {
          return Map<String, dynamic>.from(match);
        }
      }
      final disk = await _readDisk(diskKey, ttl: _ttlDisk);
      if (disk is Map) {
        return Map<String, dynamic>.from(disk);
      }
      final listDisk = await _readDisk('$_cacheKeyProductsPrefix$shopUuid', ttl: _ttlDisk);
      if (listDisk is List) {
        final match = listDisk.cast<dynamic>().firstWhere(
          (p) => (p is Map && p['uuid']?.toString() == productUuid),
          orElse: () => null,
        );
        if (match is Map) {
          return Map<String, dynamic>.from(match);
        }
      }
    }

    final res = await _client
        .get(
          Uri.parse(
            '${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/products/$productUuid',
          ),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load product');
    final map = Map<String, dynamic>.from(body as Map);
    _writeDisk(diskKey, map);
    return map;
  }

  static Future<Map<String, dynamic>> addProduct({
    required String shopUuid,
    required Map<String, String> fields,
    File? imageFile,
    List<File>? imageFiles,
  }) {
    return _saveProduct(
      method: 'POST',
      uri: Uri.parse(
        '${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/products',
      ),
      fields: fields,
      imageFile: imageFile,
      imageFiles: imageFiles,
      failureLabel: 'Failed to add product',
    );
  }

  /// Upload one product photo (S3). Used so colour→image mapping can use real URLs
  /// before the product create/update multipart is sent.
  static Future<String> uploadProductImage(File file) async {
    final token = await _token();
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/onboarding/uploads/product-image',
    );
    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    req.headers['ngrok-skip-browser-warning'] = 'true';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    final path = file.path.toLowerCase();
    final mime = path.endsWith('.png')
        ? MediaType('image', 'png')
        : path.endsWith('.webp')
            ? MediaType('image', 'webp')
            : MediaType('image', 'jpeg');
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: mime,
      ),
    );

    final streamed = await _client.send(req).timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    final body = await _parseOrThrow(res, 'Failed to upload image');
    if (body is! Map) throw Exception('Unexpected server response');
    final url = (body['url'] ?? '').toString().trim();
    if (url.isEmpty) throw Exception('Upload succeeded but no image URL returned');
    return url;
  }

  static Future<Map<String, dynamic>> updateProduct({
    required String shopUuid,
    required String productUuid,
    required Map<String, String> fields,
    File? imageFile,
    List<File>? imageFiles,
  }) {
    return _saveProduct(
      method: 'PATCH',
      uri: Uri.parse(
        '${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/products/$productUuid',
      ),
      fields: fields,
      imageFile: imageFile,
      imageFiles: imageFiles,
      failureLabel: 'Failed to update product',
    );
  }

  static Future<Map<String, dynamic>> _saveProduct({
    required String method,
    required Uri uri,
    required Map<String, String> fields,
    File? imageFile,
    List<File>? imageFiles,
    required String failureLabel,
  }) async {
    final token = await _token();
    final req = http.MultipartRequest(method, uri);
    req.headers['Accept'] = 'application/json';
    req.headers['ngrok-skip-browser-warning'] = 'true';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    fields.forEach((k, v) => req.fields[k] = v);

    Future<void> attach(String field, File file) async {
      final path = file.path.toLowerCase();
      final mime = path.endsWith('.png')
          ? MediaType('image', 'png')
          : path.endsWith('.webp')
              ? MediaType('image', 'webp')
              : MediaType('image', 'jpeg');
      req.files.add(
        await http.MultipartFile.fromPath(
          field,
          file.path,
          contentType: mime,
        ),
      );
    }

    final extras = imageFiles ?? const <File>[];
    if (extras.isNotEmpty) {
      for (final f in extras) {
        await attach('images', f);
      }
    } else if (imageFile != null) {
      await attach('image', imageFile);
    }

    final streamed = await _client.send(req).timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    final body = await _parseOrThrow(res, failureLabel);
    if (body is! Map) {
      throw Exception('Unexpected server response');
    }
    _productsCache.clear();
    return Map<String, dynamic>.from(body);
  }

  /// Download a remote product image into the app temp dir (same place the
  /// camera compress pipeline writes).
  static Future<File> downloadImageToTemp(String url) async {
    final uri = Uri.parse(url.trim());
    final res = await _client
        .get(uri, headers: {'ngrok-skip-browser-warning': 'true'})
        .timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to download image (${res.statusCode})');
    }
    final bytes = res.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception('Downloaded image is empty');
    }
    // Prefer magic bytes over URL extension (S3 keys often omit / lie about type).
    final sniffed = _sniffImageExt(bytes);
    final pathLower = uri.path.toLowerCase();
    final ext = sniffed ??
        (pathLower.endsWith('.png')
            ? 'png'
            : pathLower.endsWith('.webp')
                ? 'webp'
                : 'jpg');
    if (sniffed == null && !_looksLikeImage(bytes)) {
      throw Exception('Downloaded file is not a valid image');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/troskit_dl_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String? _sniffImageExt(List<int> bytes) {
    if (bytes.length < 12) return null;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    // WEBP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'gif';
    }
    return null;
  }

  static bool _looksLikeImage(List<int> bytes) => _sniffImageExt(bytes) != null;

  /// Warm AI route + auth (fire-and-forget). Cuts first-enhance cold failures.
  static Future<void> warmAiEnhance() async {
    try {
      final res = await _client
          .get(
            Uri.parse('${ApiConstants.baseUrl}/onboarding/ai/prompts'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) return;
    } catch (_) {}
  }

  /// ChatGPT / GPT Image enhance. Prompts are loaded server-side from ai_agent_prompts.
  ///
  /// Always upload a local [file] (camera path). Optional [imageUrl] is a
  /// server-side fallback if the file is missing.
  static Future<Map<String, dynamic>> enhanceProductImage({
    File? file,
    String? imageUrl,
    required String featureKey,
  }) async {
    final remote = (imageUrl ?? '').trim();
    final localFile = file;
    final useLocal = localFile != null && await localFile.exists();
    if (!useLocal && remote.isEmpty) {
      throw Exception('No image available for AI enhance');
    }

    final token = await _token();
    final uri = Uri.parse('${ApiConstants.baseUrl}/onboarding/ai/enhance');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    req.headers['ngrok-skip-browser-warning'] = 'true';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['feature_key'] = featureKey;

    // Always upload in-memory bytes (not fromPath). Camera temps on Android
    // often race on first enhance — fromPath sends an empty/partial file once,
    // then works on retry.
    if (useLocal) {
      final bytes = await localFile.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Photo file is empty — please retake and try again.');
      }
      final sniffed = _sniffImageExt(bytes);
      if (sniffed == null) {
        throw Exception(
          'Photo is not a valid JPEG/PNG/WebP — please retake and try again.',
        );
      }
      final subtype = sniffed == 'jpg' ? 'jpeg' : sniffed;
      final filename = 'product.$sniffed';
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('image', subtype),
        ),
      );
    } else if (remote.isNotEmpty) {
      req.fields['image_url'] = remote;
    }

    final streamed = await _client.send(req).timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);
    final body = await _parseOrThrow(res, 'AI enhance failed');
    if (body is! Map) throw Exception('Unexpected server response');
    return Map<String, dynamic>.from(body);
  }
}
