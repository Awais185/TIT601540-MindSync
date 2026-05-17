import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AnalyticsPayload {
  const AnalyticsPayload({
    required this.topCategories,
    required this.moodFrequency,
    required this.dominantMood,
    required this.verificationRatePercent,
    required this.topContentDaily,
    required this.dominantMoodDaily,
    required this.stressDaily,
  });

  final List<Map<String, dynamic>> topCategories;
  final List<Map<String, dynamic>> moodFrequency;
  final String dominantMood;
  final double verificationRatePercent;
  final List<Map<String, dynamic>> topContentDaily;
  final List<Map<String, dynamic>> dominantMoodDaily;
  final List<Map<String, dynamic>> stressDaily;
}

class AnalyticsDataService {
  AnalyticsDataService._();
  static final AnalyticsDataService instance = AnalyticsDataService._();

  Future<AnalyticsPayload> fetch(String selected) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken') ?? '';
    if (token.isEmpty) {
      return const AnalyticsPayload(
        topCategories: [],
        moodFrequency: [],
        dominantMood: 'neutral',
        verificationRatePercent: 0,
        topContentDaily: [],
        dominantMoodDaily: [],
        stressDaily: [],
      );
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    Future<Map<String, dynamic>?> getJson(String path) async {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    }

    final behavioral = await getJson(
      '/api/analytics/behavioral/?range=$selected',
    );
    final verification = await getJson(
      '/api/face-verification/analytics/?range=$selected',
    );

    final themedRows =
        (behavioral?['theme_content_categories'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => {
                'category': (row['category'] ?? row['label'] ?? 'other').toString(),
                'count': (row['count'] as num?)?.toDouble() ?? 0.0,
                'percent': (row['percent'] as num?)?.toDouble() ?? 0.0,
              },
            )
            .toList();

    final legacyCats =
        (behavioral?['top_content_categories'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

    return AnalyticsPayload(
      topCategories: themedRows.isNotEmpty ? themedRows : legacyCats,
      moodFrequency:
          (behavioral?['mood_frequency'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(),
      dominantMood: (behavioral?['dominant_mood'] as String? ?? 'neutral'),
      verificationRatePercent:
          (verification?['verification_rate_percent'] as num?)?.toDouble() ?? 0,
      topContentDaily:
          (behavioral?['top_content_daily'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(),
      dominantMoodDaily:
          (behavioral?['dominant_mood_daily'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(),
      stressDaily:
          (verification?['daily_verification'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(),
    );
  }
}
