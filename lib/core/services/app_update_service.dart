import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  static bool _checking = false;

  /// Checks for available Google Play Store updates.
  ///
  /// On Google Play Store builds:
  /// - Prompts flexible update (background download + install) or immediate update.
  /// - Silently handles errors in debug/sideloaded builds.
  static Future<void> checkForUpdate({bool immediate = false}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_checking) return;
    _checking = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (immediate || (info.immediateUpdateAllowed && !info.flexibleUpdateAllowed)) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      // Normal for sideloaded/debug builds not downloaded from Google Play Store.
      debugPrint('[AppUpdateService] Play Store update check: $e');
    } finally {
      _checking = false;
    }
  }
}
