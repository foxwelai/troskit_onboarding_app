import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

/// Maintenance payload status.
class MaintenanceStatus {
  final bool isMaintenance;
  final String title;
  final String message;
  final DateTime? updatedAt;

  static const String defaultTitle = "We'll be back soon";
  static const String defaultMessage =
      'Troskit apps are temporarily under maintenance. Please try again later.';

  const MaintenanceStatus({
    required this.isMaintenance,
    required this.title,
    required this.message,
    this.updatedAt,
  });

  factory MaintenanceStatus.off({DateTime? updatedAt}) => MaintenanceStatus(
        isMaintenance: false,
        title: defaultTitle,
        message: defaultMessage,
        updatedAt: updatedAt,
      );

  factory MaintenanceStatus.fromJson(Map<String, dynamic> json) {
    final bool isMaint = json['maintenanceMode'] == true;
    final String rawTitle = (json['title'] as String?)?.trim() ?? '';
    final String rawMessage = (json['message'] as String?)?.trim() ?? '';

    DateTime? updated;
    if (json['updatedAt'] != null) {
      try {
        updated = DateTime.tryParse(json['updatedAt'].toString());
      } catch (_) {}
    }

    return MaintenanceStatus(
      isMaintenance: isMaint,
      title: rawTitle.isNotEmpty ? rawTitle : defaultTitle,
      message: rawMessage.isNotEmpty ? rawMessage : defaultMessage,
      updatedAt: updated,
    );
  }

  @override
  String toString() =>
      'MaintenanceStatus(isMaintenance: $isMaintenance, title: $title, message: $message)';
}

/// Central manager for app maintenance mode.
///
/// 1. Cold start check via [checkStatus] before loading onboarding/home.
/// 2. Background polling every 60 seconds and on app resume.
/// 3. GoRouter refresh listenable to lock/unlock the full-screen maintenance UI.
class MaintenanceService extends ChangeNotifier with WidgetsBindingObserver {
  static final MaintenanceService instance = MaintenanceService._internal();
  MaintenanceService._internal();

  /// Shared client — reuses TCP/TLS across polls.
  static final http.Client _client = http.Client();

  MaintenanceStatus _status = MaintenanceStatus.off();
  Timer? _pollingTimer;
  bool _isChecking = false;
  bool _isMonitoring = false;

  MaintenanceStatus get status => _status;
  bool get isMaintenance => _status.isMaintenance;

  /// Starts background 60s polling + app lifecycle resume observer.
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    WidgetsBinding.instance.addObserver(this);

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkStatus();
    });
  }

  /// Stops background polling.
  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkStatus();
    }
  }

  /// Checks maintenance status.
  ///
  /// Preferred endpoint: GET /app-config/status (no-cache, no-store).
  /// Fallback endpoint: GET /app-config (legacy array format).
  Future<MaintenanceStatus> checkStatus() async {
    if (_isChecking) return _status;
    _isChecking = true;

    try {
      final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$base/app-config/status');

      final headers = {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'ngrok-skip-browser-warning': 'true',
      };

      final response =
          await _client.get(url, headers: headers).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final newStatus = MaintenanceStatus.fromJson(decoded);
          _applyStatus(newStatus);
          return _status;
        }
      }

      // If preferred endpoint returns 404, fall back to legacy GET /app-config
      if (response.statusCode == 404) {
        final legacyStatus = await _checkLegacyStatus(base, headers);
        if (legacyStatus != null) {
          _applyStatus(legacyStatus);
          return _status;
        }
      }
    } catch (e) {
      debugPrint('[MaintenanceService] checkStatus error: $e');
    } finally {
      _isChecking = false;
    }

    return _status;
  }

  Future<MaintenanceStatus?> _checkLegacyStatus(
    String base,
    Map<String, String> headers,
  ) async {
    try {
      final legacyUrl = Uri.parse('$base/app-config');
      final res = await _client
          .get(legacyUrl, headers: headers)
          .timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          bool isMaint = false;
          String? title;
          String? message;
          DateTime? updated;

          for (final item in body) {
            if (item is Map) {
              final key = item['key']?.toString();
              final val = item['value']?.toString() ?? '';

              if (key == 'maintenance_mode') {
                final normalized = val.trim().toLowerCase();
                isMaint = normalized == 'true' || normalized == '1';
              } else if (key == 'maintenance_message') {
                message = val.trim();
              } else if (key == 'maintenance_title') {
                title = val.trim();
              }

              if (item['updated_at'] != null) {
                final d = DateTime.tryParse(item['updated_at'].toString());
                if (d != null && (updated == null || d.isAfter(updated))) {
                  updated = d;
                }
              }
            }
          }

          return MaintenanceStatus(
            isMaintenance: isMaint,
            title: title?.isNotEmpty == true
                ? title!
                : MaintenanceStatus.defaultTitle,
            message: message?.isNotEmpty == true
                ? message!
                : MaintenanceStatus.defaultMessage,
            updatedAt: updated,
          );
        }
      }
    } catch (e) {
      debugPrint('[MaintenanceService] legacy app-config error: $e');
    }
    return null;
  }

  void _applyStatus(MaintenanceStatus newStatus) {
    final changed = _status.isMaintenance != newStatus.isMaintenance ||
        _status.title != newStatus.title ||
        _status.message != newStatus.message;

    _status = newStatus;
    if (changed) {
      notifyListeners();
    }
  }
}
