import 'package:flutter/material.dart';

enum BehavioralInsightKind { content, mood, stress }

class BehavioralInsightDetailScreen extends StatelessWidget {
  const BehavioralInsightDetailScreen({
    super.key,
    required this.title,
    required this.kind,
    required this.rangeLabel,
    required this.topCategories,
    required this.moodFrequency,
    required this.topContentDaily,
    required this.dominantMoodDaily,
    required this.stressDaily,
  });

  final String title;
  final BehavioralInsightKind kind;
  final String rangeLabel;
  final List<Map<String, dynamic>> topCategories;
  final List<Map<String, dynamic>> moodFrequency;
  final List<Map<String, dynamic>> topContentDaily;
  final List<Map<String, dynamic>> dominantMoodDaily;
  final List<Map<String, dynamic>> stressDaily;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A1C24),
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF6F39E8)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          _HeroCard(
            title: title,
            subtitle: 'Live insights from backend (${rangeLabel.toUpperCase()})',
          ),
          const SizedBox(height: 12),
          _buildChartCard(),
          const SizedBox(height: 12),
          _buildDailyBreakdown(),
          const SizedBox(height: 12),
          _buildRecommendationCard(),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    switch (kind) {
      case BehavioralInsightKind.content:
        final bars = topContentDaily
            .map((e) => (e['count'] as num?)?.toDouble() ?? 0)
            .toList();
        return _InsightCard(
          title: 'Most Watched in Last 7 Days',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniBarChart(values: bars),
              const SizedBox(height: 10),
              Text(
                topCategories.isEmpty
                    ? 'No content categories available yet.'
                    : 'Top category: ${(topCategories.first['category'] ?? 'other').toString().toUpperCase()} (${((topCategories.first['percent'] as num?) ?? 0).toString()}%)',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4D4F5D)),
              ),
            ],
          ),
        );
      case BehavioralInsightKind.mood:
        final bars = dominantMoodDaily
            .map((e) => (e['count'] as num?)?.toDouble() ?? 0)
            .toList();
        return _InsightCard(
          title: 'Dominant Mood Trend (7 Days)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniBarChart(values: bars, primary: const Color(0xFF0E9186)),
              const SizedBox(height: 10),
              Text(
                moodFrequency.isEmpty
                    ? 'No mood samples yet.'
                    : 'Most frequent mood: ${(moodFrequency.first['mood'] ?? 'neutral').toString().toUpperCase()}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4D4F5D)),
              ),
            ],
          ),
        );
      case BehavioralInsightKind.stress:
        final line = stressDaily
            .map((e) => (e['verification_rate_percent'] as num?)?.toDouble() ?? 0)
            .toList();
        return _InsightCard(
          title: 'Stress Indicator Trend (Verification %)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniLineChart(values: line),
              const SizedBox(height: 10),
              Text(
                line.isEmpty
                    ? 'No verification trend available yet.'
                    : 'Current consistency: ${line.last.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4D4F5D)),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildDailyBreakdown() {
    final source = switch (kind) {
      BehavioralInsightKind.content => topContentDaily,
      BehavioralInsightKind.mood => dominantMoodDaily,
      BehavioralInsightKind.stress => stressDaily,
    };
    return _InsightCard(
      title: 'Daily Breakdown',
      child: Column(
        children: source.take(7).map((entry) {
          final date = (entry['date'] ?? '').toString();
          final value = switch (kind) {
            BehavioralInsightKind.content =>
              '${(entry['category'] ?? 'other').toString()} (${entry['count'] ?? 0})',
            BehavioralInsightKind.mood =>
              '${(entry['mood'] ?? 'neutral').toString()} (${entry['count'] ?? 0})',
            BehavioralInsightKind.stress =>
              '${((entry['verification_rate_percent'] as num?) ?? 0).toStringAsFixed(1)}% verified',
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(
                      color: Color(0xFF6C7183),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1D1F28),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendationCard() {
    final recommendations = switch (kind) {
      BehavioralInsightKind.content => const [
          'Balance high-frequency entertainment content with educational windows.',
          'Set daily watch limits when one category dominates usage patterns.',
        ],
      BehavioralInsightKind.mood => const [
          'Review days where low moods appear and reduce late-night scrolling.',
          'Schedule short calm breaks after intense social media sessions.',
        ],
      BehavioralInsightKind.stress => const [
          'Track low verification-consistency days to identify stress triggers.',
          'Use short breathing resets before and after long screen sessions.',
        ],
    };
    return _InsightCard(
      title: 'Recommendations',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recommendations
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $item',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF4D4F5D),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6F39E8), Color(0xFF4D2AB5)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFD9CEFF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1F28),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({required this.values, this.primary = const Color(0xFF6F39E8)});
  final List<double> values;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(child: Text('No graph data yet')),
      );
    }
    final maxV = values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final ratio = maxV <= 0 ? 0.1 : (v / maxV).clamp(0.08, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                height: 90 * ratio,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No graph data yet')),
      );
    }
    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _LineChartPainter(values),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE09100)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = const Color(0xFFE09100);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.1 ? 1.0 : (maxV - minV);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : i * (size.width / (values.length - 1));
      final y = size.height - (((values[i] - minV) / range) * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 2.8, dotPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.values != values;
}
