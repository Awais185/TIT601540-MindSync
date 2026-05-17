import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth/permission_onboarding_screen.dart';
import 'local_auth_service.dart';
import 'screen_time_service.dart';
import 'tracking_permission_prefs.dart';

/// Usage access + Camera (critical). Screen capture is optional (native flow).
class TrackingPermissionsGate {
  TrackingPermissionsGate._();

  static const trackingSetupDoneKey = TrackingPermissionPrefs.trackingSetupDoneKey;

  static Future<bool> _coreTrackingGranted() async {
    final usage = await ScreenTimeService.instance.hasUsageAccess();
    if (!usage) return false;
    if (kIsWeb) return true;
    final cam = await Permission.camera.status;
    return cam.isGranted;
  }

  /// Usage + Camera — required before starting [ScreenTimeService].
  static Future<bool> isCoreTrackingGranted() => _coreTrackingGranted();

  /// Starts polling / sync only when core OS permissions are granted (no-op otherwise).
  static Future<void> startScreenTimeIfPermitted() async {
    if (kIsWeb) {
      ScreenTimeService.instance.start();
      return;
    }
    if (!await _coreTrackingGranted()) return;
    ScreenTimeService.instance.start();
  }

  /// True when core OS permissions are granted **and** the user finished the
  /// permission onboarding flow (pref is set in [PermissionOnboardingScreen]).
  static Future<bool> isFullyGranted() async {
    if (!await _coreTrackingGranted()) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(trackingSetupDoneKey) ?? false;
  }

  /// After username/password succeeds. Denial logs the user out and returns false.
  static Future<bool> runMandatoryAfterAuthenticatedSession(
    BuildContext context,
    LocalAuthService auth,
  ) async {
    if (await isFullyGranted()) return true;
    if (!context.mounted) return false;

    final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PermissionOnboardingScreen(auth: auth),
          ),
        ) ??
        false;

    if (!ok) {
      await auth.logout();
      return false;
    }

    if (!await _coreTrackingGranted()) {
      await auth.logout();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(trackingSetupDoneKey, true);
    return true;
  }
}
