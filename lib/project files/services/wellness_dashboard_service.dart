import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class WellnessDashboardData {
  const WellnessDashboardData({
    required this.wellbeingScore,
    required this.mentalHealthScore,
    required this.stressIndicator,
    required this.anxietyIndicator,
    required this.depressionIndicator,
    required this.dominantMoodWeek,
    required this.moodLast7,
    required this.contentBuckets,
    required this.totalChunks,
    required this.screenMinutesWeek,
    required this.facetSummary,
  });

  final int wellbeingScore;
  final int mentalHealthScore;
  final int stressIndicator;
  final int anxietyIndicator;
  final int depressionIndicator;
  final String dominantMoodWeek;
  final List<Map<String, dynamic>> moodLast7;
  final List<Map<String, dynamic>> contentBuckets;
  final int totalChunks;
  final int screenMinutesWeek;
  final String facetSummary;

  static const empty = WellnessDashboardData(
    wellbeingScore: 0,
    mentalHealthScore: 0,
    stressIndicator: 0,
    anxietyIndicator: 0,
    depressionIndicator: 0,
    dominantMoodWeek: 'neutral',
    moodLast7: [],
    contentBuckets: [],
    totalChunks: 0,
    screenMinutesWeek: 0,
    facetSummary: '',
  );

  factory WellnessDashboardData.fromJson(Map<String, dynamic> j) {
    final mood = (j['mood_last_7'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final buckets = (j['content_bucket_counts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return WellnessDashboardData(
      wellbeingScore: (j['wellbeing_score'] as num?)?.toInt() ?? 0,
      mentalHealthScore: (j['mental_health_score'] as num?)?.toInt() ?? 0,
      stressIndicator: (j['stress_indicator'] as num?)?.toInt() ?? 0,
      anxietyIndicator: (j['anxiety_indicator'] as num?)?.toInt() ?? 0,
      depressionIndicator: (j['depression_indicator'] as num?)?.toInt() ?? 0,
      dominantMoodWeek: (j['dominant_mood_week'] ?? 'neutral').toString(),
      moodLast7: mood,
      contentBuckets: buckets,
      totalChunks: (j['total_chunks'] as num?)?.toInt() ?? 0,
      screenMinutesWeek: (j['screen_minutes_week'] as num?)?.toInt() ?? 0,
      facetSummary: (j['facet_summary'] ?? '').toString(),
    );
  }
}

/// Last-7-days-derived scores for Home / reports (backed by Django).
class WellnessDashboardService {
  WellnessDashboardService._();
  static final WellnessDashboardService instance = WellnessDashboardService._();

  final ValueNotifier<WellnessDashboardData> dashboard =
      ValueNotifier<WellnessDashboardData>(WellnessDashboardData.empty);

  DateTime? _lastFetch;
  bool _inFlight = false;

  Future<void> refresh({bool force = false, int days = 7}) async {
    if (_inFlight) return;
    final now = DateTime.now();
    if (!force &&
        _lastFetch != null &&
        now.difference(_lastFetch!) < const Duration(seconds: 4)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken') ?? '';
    if (token.isEmpty) {
      dashboard.value = WellnessDashboardData.empty;
      return;
    }
    _inFlight = true;
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/dashboard/wellness/?days=$days'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      _lastFetch = DateTime.now();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        dashboard.value = WellnessDashboardData.fromJson(decoded);
      }
    } catch (_) {
      // keep last good payload
    } finally {
      _inFlight = false;
    }
  }
}
