import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;


abstract final class ApiConfig {
  ApiConfig._();

  static const String _webLocal = 'http://127.0.0.1:8000';
  static const String _androidEmulator = 'http://10.0.2.2:8000';

  /// Laptop LAN IP for physical phones (override with `DEV_LAN_HOST`).
  static const String _lanHost = String.fromEnvironment(
    'DEV_LAN_HOST',
    defaultValue: '172.24.168.80',
  );

  static const String _defineBackend = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const String _defineApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static late final String baseUrl;

  static Future<void> initialize() async {
    baseUrl = await _resolve();
  }

  static Future<String> _resolve() async {
    for (final raw in [_defineBackend, _defineApiUrl]) {
      final t = raw.trim();
      if (t.isNotEmpty) {
        return _stripTrailingSlash(t);
      }
    }

    if (kIsWeb) {
      return _webLocal;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = await DeviceInfoPlugin().androidInfo;
        if (!android.isPhysicalDevice) {
          return _androidEmulator;
        }
        return 'http://$_lanHost:8000';
      case TargetPlatform.iOS:
        final ios = await DeviceInfoPlugin().iosInfo;
        if (!ios.isPhysicalDevice) {
          return _webLocal;
        }
        return 'http://$_lanHost:8000';
      default:
        return _webLocal;
    }
  }

  static String _stripTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  /// [path] should start with `/`, e.g. `/api/auth/login/`.
  static Uri uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p');
  }
}
