import 'dart:async';

import 'package:flutter/material.dart';
import '../pages/behavioral_insight_detail_screen.dart';
import '../pages/profile_screen.dart';
import '../../services/analytics_data_service.dart';
import '../../services/screen_time_service.dart';
import '../../services/tracking_permissions_gate.dart';
import '../../ui/components/mind_sync_header.dart';
import '../../ui/layout/mindsync_layout.dart';

enum AnalyticsRange { week, day, month }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsRange selected = AnalyticsRange.week;
  late Future<AnalyticsPayload> _analyticsFuture;
  Timer? _analyticsPoll;

  @override
  void initState() {
    super.initState();
    unawaited(TrackingPermissionsGate.startScreenTimeIfPermitted());
    _analyticsFuture = AnalyticsDataService.instance.fetch(_rangeKey(selected));
    _analyticsPoll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      setState(() {
        _analyticsFuture =
            AnalyticsDataService.instance.fetch(_rangeKey(selected));
      });
    });
  }

  @override
  void dispose() {
    _analyticsPoll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: MindSyncLayout.pagePadding(context, top: 10, bottom: 100),
          children: [
            MindSyncHeader(
              onProfileTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<ScreenTimeSnapshot>(
              valueListenable: ScreenTimeService.instance.snapshot,
              builder: (_, data, _) {
                final mon =
                    data.usageStatsGranted && data.nativeTrackerConfigured;
                final fg = data.foregroundAppName.trim();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mon ? 'Live monitoring' : 'Enable Usage access',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF181A22),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fg.isNotEmpty
                            ? 'Current: $fg · today ${formatDurationShort(data.daySeconds)}'
                            : 'Screen time refreshes in real time while MindSync is open',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6E7A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // INSIGHTS & TRENDS label
            const Text(
              'INSIGHTS & TRENDS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: Color(0xFF9E9FA9),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // Focus & Balance title
            const Text(
              'Focus &\nBalance',
              style: TextStyle(
                fontSize: 32,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: Color(0xFF181A22),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Range Switch
            _RangeSwitch(
              selected: selected,
              onChanged: (value) => setState(() {
                selected = value;
                _analyticsFuture = AnalyticsDataService.instance.fetch(
                  _rangeKey(selected),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Sleep Quality Card
            const _SleepCard(),
            const SizedBox(height: 16),

            // Screen Time Card
            _ScreenTimeCard(range: selected),
            const SizedBox(height: 16),

            FutureBuilder<AnalyticsPayload>(
              future: _analyticsFuture,
              builder: (context, snapshot) {
                final payload =
                    snapshot.data ??
                    const AnalyticsPayload(
                      topCategories: [],
                      moodFrequency: [],
                      dominantMood: 'neutral',
                      verificationRatePercent: 0,
                      topContentDaily: [],
                      dominantMoodDaily: [],
                      stressDaily: [],
                    );
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _CategoriesCard(
                            categories: payload.topCategories,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _StressCard(
                            verificationRatePercent:
                                payload.verificationRatePercent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MoodFrequencyCard(
                      moodFrequency: payload.moodFrequency,
                      dominantMood: payload.dominantMood,
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // Behavioral Insights
            const Text(
              'Behavioral Insights',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1F28),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<AnalyticsPayload>(
              future: _analyticsFuture,
              builder: (context, snapshot) {
                final payload =
                    snapshot.data ??
                    const AnalyticsPayload(
                      topCategories: [],
                      moodFrequency: [],
                      dominantMood: 'neutral',
                      verificationRatePercent: 0,
                      topContentDaily: [],
                      dominantMoodDaily: [],
                      stressDaily: [],
                    );
                final topCategory = payload.topCategories.isNotEmpty
                    ? (payload.topCategories.first['category']?.toString() ??
                          'other')
                    : 'other';
                final topCategoryPercent = payload.topCategories.isNotEmpty
                    ? ((payload.topCategories.first['percent'] as num?)
                              ?.toDouble() ??
                          0)
                    : 0;
                return _InsightTile(
                  icon: Icons.movie_filter_rounded,
                  iconBg: const Color(0xFFF0EBFF),
                  iconColor: const Color(0xFF6F39E8),
                  title: 'Most Watched Content Type',
                  subtitle:
                      '${topCategory.toUpperCase()} leads at ${topCategoryPercent.toStringAsFixed(0)}%',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BehavioralInsightDetailScreen(
                          title: 'Most Watched Content Type',
                          kind: BehavioralInsightKind.content,
                          rangeLabel: _rangeKey(selected),
                          topCategories: payload.topCategories,
                          moodFrequency: payload.moodFrequency,
                          topContentDaily: payload.topContentDaily,
                          dominantMoodDaily: payload.dominantMoodDaily,
                          stressDaily: payload.stressDaily,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<AnalyticsPayload>(
              future: _analyticsFuture,
              builder: (context, snapshot) {
                final payload =
                    snapshot.data ??
                    const AnalyticsPayload(
                      topCategories: [],
                      moodFrequency: [],
                      dominantMood: 'neutral',
                      verificationRatePercent: 0,
                      topContentDaily: [],
                      dominantMoodDaily: [],
                      stressDaily: [],
                    );
                return _InsightTile(
                  icon: Icons.mood_rounded,
                  iconBg: const Color(0xFFDDF7F4),
                  iconColor: const Color(0xFF0E9186),
                  title: 'Dominant Mood',
                  subtitle:
                      '${payload.dominantMood.toUpperCase()} appears most frequently',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BehavioralInsightDetailScreen(
                          title: 'Dominant Mood',
                          kind: BehavioralInsightKind.mood,
                          rangeLabel: _rangeKey(selected),
                          topCategories: payload.topCategories,
                          moodFrequency: payload.moodFrequency,
                          topContentDaily: payload.topContentDaily,
                          dominantMoodDaily: payload.dominantMoodDaily,
                          stressDaily: payload.stressDaily,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<AnalyticsPayload>(
              future: _analyticsFuture,
              builder: (context, snapshot) {
                final payload =
                    snapshot.data ??
                    const AnalyticsPayload(
                      topCategories: [],
                      moodFrequency: [],
                      dominantMood: 'neutral',
                      verificationRatePercent: 0,
                      topContentDaily: [],
                      dominantMoodDaily: [],
                      stressDaily: [],
                    );
                return _InsightTile(
                  icon: Icons.psychology_alt_rounded,
                  iconBg: const Color(0xFFFFF4E5),
                  iconColor: const Color(0xFFE09100),
                  title: 'Stress Indicators',
                  subtitle:
                      'Face verification success: ${payload.verificationRatePercent.toStringAsFixed(0)}%',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BehavioralInsightDetailScreen(
                          title: 'Stress Indicators',
                          kind: BehavioralInsightKind.stress,
                          rangeLabel: _rangeKey(selected),
                          topCategories: payload.topCategories,
                          moodFrequency: payload.moodFrequency,
                          topContentDaily: payload.topContentDaily,
                          dominantMoodDaily: payload.dominantMoodDaily,
                          stressDaily: payload.stressDaily,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _rangeKey(AnalyticsRange range) {
    return switch (range) {
      AnalyticsRange.day => 'day',
      AnalyticsRange.week => 'week',
      AnalyticsRange.month => 'month',
    };
  }
}

// Range Switch Widget
class _RangeSwitch extends StatelessWidget {
  const _RangeSwitch({required this.selected, required this.onChanged});

  final AnalyticsRange selected;
  final ValueChanged<AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildSwitchItem('Week', AnalyticsRange.week),
          _buildSwitchItem('Day', AnalyticsRange.day),
          _buildSwitchItem('Month', AnalyticsRange.month),
        ],
      ),
    );
  }

  Widget _buildSwitchItem(String text, AnalyticsRange value) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6F39E8) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6F39E8).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF3A3B46),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Sleep Quality Card
class _SleepCard extends StatelessWidget {
  const _SleepCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SLEEP TIME',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Color(0xFF9A97AD),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '0h, 0m',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                    color: Color(0xFF181A22),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sleep tracking coming soon',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFBDF2EC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF59DDD0),
                child: Icon(
                  Icons.nightlight_round,
                  size: 22,
                  color: Color(0xFF0F2E34),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Screen Time Card with Bar Chart
class _ScreenTimeCard extends StatelessWidget {
  const _ScreenTimeCard({required this.range});

  final AnalyticsRange range;

  @override
  Widget build(BuildContext context) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'AVG. SCREEN TIME',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Color(0xFF9A97AD),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Icon(Icons.show_chart, size: 18, color: Color(0xFFB8B9C4)),
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<ScreenTimeSnapshot>(
            valueListenable: ScreenTimeService.instance.snapshot,
            builder: (context, data, _) {
              final seconds = switch (range) {
                AnalyticsRange.day => data.daySeconds,
                AnalyticsRange.week => data.weekSeconds,
                AnalyticsRange.month => data.monthSeconds,
              };
              return Text(
                '${formatDurationShort(seconds)}${data.recordingActive ? ' · REC' : ''}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                  color: data.recordingActive
                      ? const Color(0xFF0E9186)
                      : const Color(0xFF181A22),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ValueListenableBuilder<ScreenTimeSnapshot>(
              valueListenable: ScreenTimeService.instance.snapshot,
              builder: (context, data, _) {
                final heights = switch (range) {
                  AnalyticsRange.day =>
                    data.analyticsDayBarHeights.length >= 7
                        ? data.analyticsDayBarHeights.sublist(0, 7)
                        : ScreenTimeSnapshot.analyticsBarsNoData,
                  AnalyticsRange.week =>
                    data.analyticsWeekBarHeights.length >= 7
                        ? data.analyticsWeekBarHeights.sublist(0, 7)
                        : ScreenTimeSnapshot.analyticsBarsNoData,
                  AnalyticsRange.month =>
                    data.analyticsMonthBarHeights.length >= 7
                        ? data.analyticsMonthBarHeights.sublist(0, 7)
                        : ScreenTimeSnapshot.analyticsBarsNoData,
                };
                double maxBar = heights.isEmpty
                    ? 1
                    : heights.reduce((a, b) => a > b ? a : b);
                if (maxBar <= 0) maxBar = 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final h = heights[index].clamp(8.0, 80.0);
                    final isHighest = heights[index] == maxBar;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isHighest
                                ? const Color(0xFF6F39E8)
                                : const Color(0xFFE3E4EA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) {
              return Text(
                day,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9DA0AB),
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// Categories Card with Donut Chart
class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.categories});

  final List<Map<String, dynamic>> categories;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORIES',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: Color(0xFF9A97AD),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              final rows = categories.take(3).toList();
              if (rows.isEmpty) {
                return const Text(
                  'No categorized content yet',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9DA0AB)),
                );
              }
              final palette = [
                const Color(0xFF6F39E8),
                const Color(0xFF60D5C8),
                const Color(0xFF9DA0AB),
              ];
              return Column(
                children: List.generate(rows.length, (index) {
                  final row = rows[index];
                  final label = (row['category']?.toString() ?? 'other');
                  final percent = (row['percent'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == rows.length - 1 ? 0 : 12,
                    ),
                    child: _CategoryLine(
                      label: label.isEmpty
                          ? 'Other'
                          : '${label[0].toUpperCase()}${label.substring(1)}',
                      value: '${percent.toStringAsFixed(0)}%',
                      progress: (percent / 100).clamp(0, 1),
                      color: palette[index % palette.length],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4D4F5D),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4D4F5D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE9EAF1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// Stress Card
class _StressCard extends StatelessWidget {
  const _StressCard({required this.verificationRatePercent});

  final double verificationRatePercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B66D8),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B66D8).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.spa, size: 20, color: Color(0xFFA8D7FF)),
          const Spacer(),
          const Text(
            'STRESS',
            style: TextStyle(
              color: Color(0xFFC3E2FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              verificationRatePercent >= 75 ? 'Stable' : 'Watch',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            'Verify ${verificationRatePercent.toStringAsFixed(0)}%',
            style: const TextStyle(color: Color(0xFFC3E2FF), fontSize: 11),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 56,
            child: Divider(color: Color(0x66FFFFFF), thickness: 3),
          ),
        ],
      ),
    );
  }
}

// Mood Frequency Card
class _MoodFrequencyCard extends StatelessWidget {
  const _MoodFrequencyCard({
    required this.moodFrequency,
    required this.dominantMood,
  });

  final List<Map<String, dynamic>> moodFrequency;
  final String dominantMood;

  @override
  Widget build(BuildContext context) {
    final moods = moodFrequency.take(10).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'MOOD FREQUENCY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Color(0xFF9A97AD),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                'TOP: ${dominantMood.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A7ACC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: moods.isEmpty
                ? const Center(
                    child: Text(
                      'No mood samples yet',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9DA0AB)),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: moods.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final mood = moods[index];
                      final label = (mood['mood']?.toString() ?? 'neutral')
                          .toLowerCase();
                      final bg = label.contains('happy')
                          ? const Color(0xFFC6F2ED)
                          : label.contains('sad') || label.contains('angry')
                          ? const Color(0xFFFFE0E0)
                          : const Color(0xFFD9F8F4);
                      final fg =
                          label.contains('sad') || label.contains('angry')
                          ? const Color(0xFFB13030)
                          : const Color(0xFF4CA49B);
                      final percent =
                          (mood['percent'] as num?)?.toDouble() ?? 0;
                      return Tooltip(
                        message:
                            '${label.toUpperCase()} ${percent.toStringAsFixed(1)}%',
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: bg,
                          child: Icon(
                            label.contains('happy')
                                ? Icons.sentiment_very_satisfied
                                : label.contains('sad')
                                ? Icons.sentiment_dissatisfied
                                : label.contains('angry')
                                ? Icons.sentiment_very_dissatisfied
                                : Icons.sentiment_neutral,
                            size: 16,
                            color: fg,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// History Tile Widget
class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8E2FA), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6F39E8).withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D1F28),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF838391),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFFBCBCC8),
            ),
          ],
        ),
      ),
    );
  }
}
