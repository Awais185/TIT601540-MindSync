import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ParentalAppRule {
  const ParentalAppRule({
    required this.packageName,
    required this.appLabel,
    required this.blocked,
  });

  final String packageName;
  final String appLabel;
  final bool blocked;
}

class ParentalControlService {
  static const MethodChannel _channel = MethodChannel('mindsync/screen_time');

  /// Persisted blocked package ids mirrored to native HOME blocker ([AppBlockerService]).
  static const blockedPkgsStorageKey = 'parental.home_block_packages.v1';

  Future<void> _persistBlocked(Set<String> pkgs) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = pkgs.where((s) => s.isNotEmpty).toList()..sort();
    await prefs.setString(blockedPkgsStorageKey, jsonEncode(sorted));
  }

  Future<Set<String>> _readBlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(blockedPkgsStorageKey);
    if (raw == null || raw.isEmpty) return {};
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
  }

  Future<void> syncNativeHomeBlocker(Set<String> packages) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('appBlockerSetBlockedApps', {
        'packages': packages.toList(),
      });
    } catch (_) {}
  }

  /// Call after login so native blocker restores from prefs without reopening parental UI.
  static Future<void> restoreNativeHomeBlockerFromPrefs() async {
    if (kIsWeb) return;
    await ParentalControlService()._restoreNativeHomeBlockerFromPrefsImpl();
  }

  Future<void> _restoreNativeHomeBlockerFromPrefsImpl() async {
    await syncNativeHomeBlocker(await _readBlocked());
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<List<ParentalAppRule>> fetchRules() async {
    final token = await _token();
    if (token == null) return const [];
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/parent/blocked-apps/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final apps = (json['apps'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final mapped = apps
        .map(
          (a) => ParentalAppRule(
            packageName: (a['package_name'] ?? '').toString(),
            appLabel: (a['app_label'] ?? a['package_name'] ?? '').toString(),
            blocked: (a['blocked'] as bool?) ?? false,
          ),
        )
        .where((r) => r.packageName.isNotEmpty)
        .toList();

    final results = <ParentalAppRule>[];
    var tiktokShown = false;
    for (final rule in mapped) {
      final key = '${rule.packageName} ${rule.appLabel}'.toLowerCase();
      final isTikTokVariant =
          key.contains('tiktok') ||
          key.contains('musically') ||
          key.contains('trill') ||
          key.contains('tiktok lite');
      if (isTikTokVariant) {
        if (tiktokShown) continue;
        tiktokShown = true;
      }
      results.add(rule);
    }

    final blockedPkgs =
        results.where((r) => r.blocked).map((r) => r.packageName).toSet();
    await _persistBlocked(blockedPkgs);
    await syncNativeHomeBlocker(blockedPkgs);

    return results;
  }

  Future<bool> setBlocked({
    required String packageName,
    required bool blocked,
  }) async {
    final token = await _token();
    if (token == null) return false;
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/parent/blocked-apps/update/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'package_name': packageName,
        'blocked': blocked,
      }),
    );
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok) return false;

    final existing = await _readBlocked();
    if (blocked) {
      existing.add(packageName);
    } else {
      existing.remove(packageName);
    }
    await _persistBlocked(existing);

    if (!kIsWeb) {
      try {
        await _channel.invokeMethod('setBlockedAppNow', {
          'packageName': packageName,
          'blocked': blocked,
        });
      } catch (_) {
        // Backend state already saved; native sync will retry via poller.
      }
      await syncNativeHomeBlocker(existing);
    }
    return true;
  }

  Future<void> applyLocalPolicy({
    required int socialMinutesLimit,
    required int gamingMinutesLimit,
    required int entertainmentMinutesLimit,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setParentalPolicy', {
        'socialLimitMinutes': socialMinutesLimit,
        'gamingLimitMinutes': gamingMinutesLimit,
        'entertainmentLimitMinutes': entertainmentMinutesLimit,
      });
    } catch (_) {}
  }
}
