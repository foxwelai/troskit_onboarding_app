import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/api_constants.dart';

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
  static _CacheEntry<List<dynamic>>? _categoriesCache;
  static _CacheEntry<List<dynamic>>? _shopsCache;
  static final Map<String, _CacheEntry<Map<String, dynamic>>> _shopDetailsCache = {};
  static final Map<String, _CacheEntry<List<dynamic>>> _productsCache = {};

  static const _ttl5Min = Duration(minutes: 5);
  static const _ttl3Min = Duration(minutes: 3);

  static void clearCache({
    bool categories = true,
    bool shops = true,
    String? shopUuid,
  }) {
    if (categories) _categoriesCache = null;
    if (shops) {
      _shopsCache = null;
      _shopDetailsCache.clear();
    }
    if (shopUuid != null) {
      _productsCache.remove(shopUuid);
      _shopDetailsCache.remove(shopUuid);
    } else {
      _productsCache.clear();
    }
  }

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('employee_token');
  }

  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> employee,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employee_token', token);
    await prefs.setString('employee_json', jsonEncode(employee));
  }

  static Future<Map<String, dynamic>?> currentEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('employee_json');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('employee_token');
    await prefs.remove('employee_json');
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
    final res = await http
        .post(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Login failed');
    }
    await saveSession(
      token: body['token'] as String,
      employee: Map<String, dynamic>.from(body['employee'] as Map),
    );
    return body;
  }

  static Future<Map<String, dynamic>> me() async {
    final res = await http
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
    return map;
  }

  static Future<List<dynamic>> listCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categoriesCache != null && !_categoriesCache!.isExpired(_ttl5Min)) {
      return _categoriesCache!.data;
    }
    final res = await http
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
    _categoriesCache = _CacheEntry(List<dynamic>.from(list));
    return _categoriesCache!.data;
  }

  static Future<Map<String, dynamic>> createCategory({
    required String categoryName,
    String? description,
  }) async {
    final res = await http
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
    if (!forceRefresh && _shopsCache != null && !_shopsCache!.isExpired(_ttl3Min)) {
      return _shopsCache!.data;
    }
    final res = await http
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/shops'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load shops');
    final list = body as List<dynamic>;
    _shopsCache = _CacheEntry(list);
    return list;
  }

  static _CacheEntry<List<dynamic>>? _activityCache;

  static Future<List<dynamic>> listActivityFeed({bool forceRefresh = false}) async {
    const ttl = Duration(minutes: 2);
    if (!forceRefresh && _activityCache != null && !_activityCache!.isExpired(ttl)) {
      return _activityCache!.data;
    }
    final res = await http
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
    final cached = _shopDetailsCache[shopUuid];
    if (!forceRefresh && cached != null && !cached.isExpired(_ttl3Min)) {
      return cached.data;
    }
    final res = await http
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/shops/$shopUuid'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load shop');
    final map = Map<String, dynamic>.from(body as Map);
    _shopDetailsCache[shopUuid] = _CacheEntry(map);
    return map;
  }

  static Future<Map<String, dynamic>> requestEcom({
    required String shopUuid,
    double? latitude,
    double? longitude,
    bool enabled = true,
  }) async {
    final res = await http
        .post(
          Uri.parse(
            '${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/ecom/request',
          ),
          headers: await _authHeaders(),
          body: jsonEncode({
            'enabled': enabled,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to request ECOM');
    _shopDetailsCache.remove(shopUuid);
    _shopsCache = null;
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Map<String, dynamic>> createShop(Map<String, dynamic> payload) async {
    final res = await http
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
    final cached = _productsCache[shopUuid];
    if (!forceRefresh && cached != null && !cached.isExpired(_ttl3Min)) {
      return cached.data;
    }
    final res = await http
        .get(
          Uri.parse('${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/products'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load products');
    final list = body as List<dynamic>;
    _productsCache[shopUuid] = _CacheEntry(list);
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
    final res = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Catalog lookup failed');
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Map<String, dynamic>> getProduct({
    required String shopUuid,
    required String productUuid,
  }) async {
    final res = await http
        .get(
          Uri.parse(
            '${ApiConstants.baseUrl}/onboarding/shops/$shopUuid/products/$productUuid',
          ),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _parseOrThrow(res, 'Failed to load product');
    return Map<String, dynamic>.from(body as Map);
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

    final streamed = await req.send().timeout(const Duration(seconds: 90));
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

    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    final body = await _parseOrThrow(res, failureLabel);
    if (body is! Map) {
      throw Exception('Unexpected server response');
    }
    _productsCache.clear();
    return Map<String, dynamic>.from(body);
  }

  /// Download a remote product image into a temp file (for AI enhance on existing photos).
  static Future<File> downloadImageToTemp(String url) async {
    final uri = Uri.parse(url);
    final res = await http
        .get(uri, headers: {'ngrok-skip-browser-warning': 'true'})
        .timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to download image (${res.statusCode})');
    }
    final pathLower = uri.path.toLowerCase();
    final ext = pathLower.endsWith('.png')
        ? 'png'
        : pathLower.endsWith('.webp')
            ? 'webp'
            : 'jpg';
    final file = File(
      '${Directory.systemTemp.path}/troskit_dl_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file;
  }

  /// ChatGPT / GPT Image enhance. Prompts are loaded server-side from ai_agent_prompts.
  static Future<Map<String, dynamic>> enhanceProductImage({
    required File file,
    required String featureKey,
  }) async {
    final token = await _token();
    final uri = Uri.parse('${ApiConstants.baseUrl}/onboarding/ai/enhance');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    req.headers['ngrok-skip-browser-warning'] = 'true';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['feature_key'] = featureKey;

    final path = file.path.toLowerCase();
    final mime = path.endsWith('.png')
        ? MediaType('image', 'png')
        : path.endsWith('.webp')
            ? MediaType('image', 'webp')
            : MediaType('image', 'jpeg');
    req.files.add(
      await http.MultipartFile.fromPath('file', file.path, contentType: mime),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);
    final body = await _parseOrThrow(res, 'AI enhance failed');
    if (body is! Map) throw Exception('Unexpected server response');
    return Map<String, dynamic>.from(body);
  }
}
