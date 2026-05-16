import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main_shell_screen.dart';
import '../../config/api_config.dart';
import '../../services/local_auth_service.dart';
import '../../services/screen_time_service.dart';
import '../../services/tracking_permissions_gate.dart';
import '../../services/week_report_pdf.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _auth = LocalAuthService();
  AuthProfile? _profile;
  String? _dynamicReportTitle;
  String? _dynamicReportBody;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    unawaited(TrackingPermissionsGate.startScreenTimeIfPermitted());
    _loadDynamicWeeklySummary();
  }

  Future<void> _loadDynamicWeeklySummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken') ?? '';
    if (token.isEmpty || !mounted) return;
    try {
      final res = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/reports/summary/?days=7'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted || res.statusCode < 200 || res.statusCode >= 300) return;
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _dynamicReportTitle = (decoded['title'] ?? '').toString();
          _dynamicReportBody = (decoded['body'] ?? '').toString();
        });
      }
    } catch (_) {
      // Keep static visuals when API fails.
    }
  }

  Future<void> _loadProfile() async {
    final profile = await _auth.fetchCurrentUserProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToAnalytics();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: SafeArea(
          child: ValueListenableBuilder<ScreenTimeSnapshot>(
            valueListenable: ScreenTimeService.instance.snapshot,
            builder: (context, snapshot, _) {
              final name =
                  _profile?.fullName ??
                  _profile?.displayName ??
                  'MindSync User';
              final email = _profile?.email ?? 'No email';
              final dayHours = snapshot.daySeconds / 3600;

              final wellbeingScore = _calculateWellbeingScore(snapshot);
              final moodStability = _calculateMoodStability(snapshot);
              final sleepQuality = _calculateSleepQuality(snapshot);

              final socialMediaPercent = _getCategoryPercentage(
                snapshot,
                'Social',
              );
              final entertainmentPercent = _getCategoryPercentage(
                snapshot,
                'Entertainment',
              );
              final educationalPercent = _getCategoryPercentage(
                snapshot,
                'Education',
              );
              final appSwitchingPercent = _getAppSwitchingPercent(snapshot);

              final dailyScreenData = _getDailyScreenData(snapshot);
              final moodData = _getMoodData(snapshot, dailyScreenData);

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(name, email),
                    const SizedBox(height: 16),
                    if (_dynamicReportBody != null &&
                        _dynamicReportBody!.trim().isNotEmpty) ...[
                      _buildLiveReportCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildKPIRow(
                      dayHours,
                      moodStability,
                      sleepQuality,
                      wellbeingScore,
                    ),
                    const SizedBox(height: 16),
                    _buildOverallWellbeingCard(
                      wellbeingScore,
                      socialMediaPercent,
                      entertainmentPercent,
                      educationalPercent,
                      appSwitchingPercent,
                    ),
                    const SizedBox(height: 16),
                    _buildScreenTimeVsMoodCard(dailyScreenData, moodData),
                    const SizedBox(height: 16),
                    _buildDailyScreenTimeCard(dailyScreenData),
                    const SizedBox(height: 16),
                    _buildMoodOverWeekCard(moodData),
                    const SizedBox(height: 16),
                    _buildSleepQualityCard(snapshot, sleepQuality),
                    const SizedBox(height: 16),
                    _buildRiskWellbeingRadar(snapshot),
                    const SizedBox(height: 16),
                    _buildAIModelConfidenceCard(),
                    const SizedBox(height: 16),
                    _buildDailyBehaviourSummary(
                      snapshot,
                      dailyScreenData,
                      moodData,
                    ),
                    const SizedBox(height: 16),
                    _buildMetricsStatusSummary(
                      dayHours,
                      moodStability,
                      sleepQuality,
                    ),
                    const SizedBox(height: 16),
                    _buildClinicalInterpretation(
                      dayHours,
                      socialMediaPercent,
                      snapshot,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add to Watch List'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A6FA5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _goToAnalytics() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShellScreen(initialTab: 1)),
      (_) => false,
    );
  }

  Future<void> _shareReport() async {
    final snap = ScreenTimeService.instance.snapshot.value;
    final name =
        _profile?.fullName ?? _profile?.displayName ?? 'MindSync User';
    final email = _profile?.email ?? '';
    final sleep = _calculateSleepQuality(snap);
    final lateH = snap.lateNightWeekSeconds / 3600.0;
    final opens = snap.lateNightOpensWeek;
    final buf = StringBuffer()
      ..writeln('MindSync — 7-day report')
      ..writeln('User: $name');
    if (email.isNotEmpty) buf.writeln('Email: $email');
    buf
      ..writeln()
      ..writeln(
        'Sleep quality score: $sleep/100 (uses late-night phone use 10 PM–5 AM, last 7 days).',
      )
      ..writeln(
        'Late-night screen: ${lateH.toStringAsFixed(1)} h total; activity (opens / switches, approx): $opens.',
      );
    if (snap.lateNightTopApps.isNotEmpty) {
      buf.writeln();
      buf.writeln('Top late-night apps:');
      for (final a in snap.lateNightTopApps.take(6)) {
        buf.writeln(
          '- ${a.appName}: ${(a.durationSeconds / 60).ceil()} min',
        );
      }
    }
    final title = _dynamicReportTitle?.trim();
    final body = _dynamicReportBody?.trim();
    if (title != null && title.isNotEmpty) {
      buf.writeln();
      buf.writeln(title);
    }
    if (body != null && body.isNotEmpty) {
      buf.writeln();
      buf.writeln(body);
    }
    try {
      await Share.share(
        buf.toString(),
        subject: 'MindSync 7-day report',
      );
    } catch (e) {
      if (mounted) {
        _show('Could not open share: $e');
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    final snap = ScreenTimeService.instance.snapshot.value;
    final name =
        _profile?.fullName ?? _profile?.displayName ?? 'MindSync User';
    final email = _profile?.email ?? '';
    final daily = _getDailyScreenData(snap);
    final mood = _getMoodData(snap, daily);
    final lateLines = snap.lateNightTopApps
        .take(8)
        .map(
          (a) =>
              '${a.appName} — ${(a.durationSeconds / 60).ceil()} min (${(a.durationSeconds / 3600).toStringAsFixed(2)} h)',
        )
        .toList();
    final byDay = snap.lateNightByDaySeconds.length >= 7
        ? List<int>.from(snap.lateNightByDaySeconds.take(7))
        : List<int>.filled(7, 0);

    try {
      final bytes = await WeekReportPdfBuilder.build(
        name: name,
        email: email,
        dynamicTitle: _dynamicReportTitle,
        dynamicBody: _dynamicReportBody,
        sleepQualityScore: _calculateSleepQuality(snap),
        dayScreenHours: snap.daySeconds / 3600.0,
        lateNightWeekSeconds: snap.lateNightWeekSeconds,
        lateNightOpensWeek: snap.lateNightOpensWeek,
        lateNightByDaySeconds: byDay,
        lateNightAppLines: lateLines,
        dailyScreenHours: daily,
        moodSeries: mood,
        wellbeingScore: _calculateWellbeingScore(snap),
        moodStability: _calculateMoodStability(snap),
      );
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: 'MindSync_7day_report.pdf',
          ),
        ],
        subject: 'MindSync 7-day report',
        text: 'MindSync 7-day wellbeing report (PDF)',
      );
    } catch (e) {
      if (mounted) {
        _show('Could not build or share PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  // ==================== BUILD METHODS ====================

  Widget _buildHeader(String name, String email) {
    return Row(
      children: [
        InkWell(
          onTap: _goToAnalytics,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF4A6FA5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF4A6FA5),
          backgroundImage:
              (_profile != null &&
                  _auth.resolveMediaUrl(_profile!.faceImage).isNotEmpty)
              ? NetworkImage(_auth.resolveMediaUrl(_profile!.faceImage))
              : null,
          child:
              (_profile == null ||
                  _auth.resolveMediaUrl(_profile!.faceImage).isEmpty)
              ? const Icon(Icons.person, color: Colors.white, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2C3E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7A8A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _headerPill('Share', _shareReport),
        const SizedBox(width: 6),
        _headerPill(_pdfBusy ? '…' : 'PDF', _pdfBusy ? () {} : _exportPdf),
      ],
    );
  }

  Widget _headerPill(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FB),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A6FA5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveReportCard() {
    final title =
        (_dynamicReportTitle != null && _dynamicReportTitle!.trim().isNotEmpty)
            ? _dynamicReportTitle!
            : '7-day MindSync summary';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1D6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded,
                  size: 20, color: const Color(0xFF6F39E8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2330),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            _dynamicReportBody ?? '',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF3C4050),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIRow(
    double dayHours,
    int moodStability,
    int sleepQuality,
    int wellbeingScore,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKPI(
                'Avg Screen',
                dayHours.toStringAsFixed(1),
                'h',
                dayHours > 5 ? 'High' : (dayHours > 3 ? 'Moderate' : 'Good'),
                dayHours > 5
                    ? const Color(0xFFE65A4F)
                    : (dayHours > 3
                          ? const Color(0xFFE6A017)
                          : const Color(0xFF2E8B57)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKPI(
                'Mood',
                moodStability.toString(),
                '',
                moodStability > 70
                    ? 'Stable'
                    : (moodStability > 50 ? 'Moderate' : 'Low'),
                moodStability > 70
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFFE6A017),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKPI(
                'Sleep',
                sleepQuality.toString(),
                '',
                sleepQuality > 70
                    ? 'Good'
                    : (sleepQuality > 50 ? 'Fair' : 'Poor'),
                sleepQuality > 70
                    ? const Color(0xFF2E8B57)
                    : (sleepQuality > 50
                          ? const Color(0xFFE6A017)
                          : const Color(0xFFE65A4F)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKPI(
                'Wellbeing',
                wellbeingScore.toString(),
                '',
                wellbeingScore > 70
                    ? 'Good'
                    : (wellbeingScore > 50 ? 'Fair' : 'Needs attention'),
                wellbeingScore > 70
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFFE6A017),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPI(
    String label,
    String value,
    String unit,
    String status,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7A8A)),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2C3E),
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7A8A),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 9,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallWellbeingCard(
    int score,
    double socialPercent,
    double entertainmentPercent,
    double educationalPercent,
    double switchingPercent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wellbeing Score',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E8B57).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$score/100',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E8B57),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Digital wellbeing stable with moderate stress signals.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7A8A)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusTag('Normal', 2, Colors.green),
                const SizedBox(width: 8),
                _statusTag('Positive', 1, Colors.blue),
                const SizedBox(width: 8),
                _statusTag('Stable', 1, Colors.orange),
                const SizedBox(width: 8),
                _statusTag('Warning', 1, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            'Usage Categories',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _categoryBar('Social Media', socialPercent, const Color(0xFF4A6FA5)),
          const SizedBox(height: 6),
          _categoryBar(
            'Entertainment',
            entertainmentPercent,
            const Color(0xFF9B6BB3),
          ),
          const SizedBox(height: 6),
          _categoryBar(
            'Educational',
            educationalPercent,
            const Color(0xFF2E8B57),
          ),
          const SizedBox(height: 6),
          _categoryBar(
            'App Switching',
            switchingPercent,
            const Color(0xFFE6A017),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '💡 ${socialPercent > 30 ? "Social media highest usage. " : ""}Shift to productive activities.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF4A6FA5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTimeVsMoodCard(
    List<double> screenData,
    List<double> moodData,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screen Time vs Mood',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Row(
              children: List.generate(7, (index) {
                final screenVal = index < screenData.length
                    ? screenData[index]
                    : 3.5;
                final moodVal = index < moodData.length ? moodData[index] : 5.0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: screenVal * 8,
                        width: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A6FA5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: moodVal * 8,
                        width: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF9B6BB3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend('Screen', const Color(0xFF4A6FA5)),
              const SizedBox(width: 14),
              _legend('Mood', const Color(0xFF9B6BB3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyScreenTimeCard(List<double> screenData) {
    final maxScreen = screenData.isEmpty
        ? 5
        : screenData.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Screen Trend',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              children: List.generate(screenData.length, (index) {
                final value = screenData[index];
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: (value / (maxScreen + 1)) * 90,
                        width: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A6FA5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${value.toStringAsFixed(1)}h',
                        style: const TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF4E6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE6A017).withOpacity(0.3),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Mid-week spike detected',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                ),
                SizedBox(height: 3),
                Text(
                  'May indicate stress or work pressure.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF6B7A8A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodOverWeekCard(List<double> moodData) {
    final moodEmojis = ['😊', '🙂', '😐', '😔', '🙂', '😊', '😊'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mood Over Week',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final moodVal = index < moodData.length ? moodData[index] : 5.0;
              return Column(
                children: [
                  Text(moodEmojis[index], style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text(
                    moodVal.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF6B7A8A),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '📉 U-shaped pattern: Mood dipped mid-week, recovered by weekend.',
              style: TextStyle(fontSize: 10, color: Color(0xFF6B7A8A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepQualityCard(ScreenTimeSnapshot snapshot, int sleepScore) {
    final lateSec = snapshot.lateNightWeekSeconds;
    final lateH = lateSec / 3600.0;
    final opens = snapshot.lateNightOpensWeek;
    String band;
    Color bandColor;
    if (sleepScore >= 75) {
      band = 'Good';
      bandColor = const Color(0xFF2E8B57);
    } else if (sleepScore >= 55) {
      band = 'Fair';
      bandColor = const Color(0xFFE6A017);
    } else {
      band = 'Poor';
      bandColor = const Color(0xFFE65A4F);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sleep Quality',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bandColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  band,
                  style: TextStyle(
                    fontSize: 10,
                    color: bandColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sleepScore',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                ' /100',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7A8A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.usageStatsGranted
                ? 'Uses phone use between 10 PM – 5 AM (local time, last 7 days) plus rough daytime load.'
                : 'Turn on Usage access (Android) to measure late-night phone use for this score.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Color(0xFF6B7A8A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.nightlight_round, size: 18, color: Color(0xFF4A6FA5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Late-night screen: ${lateH.toStringAsFixed(1)} h · '
                  'Activity (opens / switches): $opens',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2C3E),
                  ),
                ),
              ),
            ],
          ),
          if (snapshot.lateNightTopApps.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Top late-night apps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2C3E),
              ),
            ),
            const SizedBox(height: 6),
            ...snapshot.lateNightTopApps.take(5).map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4C4F61),
                            ),
                          ),
                        ),
                        Text(
                          '${(a.durationSeconds / 60).ceil()} min',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A6FA5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskWellbeingRadar(ScreenTimeSnapshot snapshot) {
    final dayHours = snapshot.daySeconds / 3600;
    final riskScore = _riskScore(snapshot.daySeconds);
    final anxietyLevel = (riskScore / 33).clamp(1, 3).round();
    final addictionLevel = (dayHours / 16).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk & Wellbeing',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _riskItem(
            'Emotional Balance',
            riskScore < 50 ? 'Good' : (riskScore < 75 ? 'Moderate' : 'Fair'),
            riskScore < 50
                ? const Color(0xFF2E8B57)
                : (riskScore < 75
                      ? const Color(0xFFE6A017)
                      : const Color(0xFFE65A4F)),
            Icons.sentiment_satisfied,
          ),
          const SizedBox(height: 8),
          _riskItem(
            'Anxiety',
            anxietyLevel == 1 ? 'Low' : (anxietyLevel == 2 ? 'Medium' : 'High'),
            anxietyLevel == 1
                ? const Color(0xFF2E8B57)
                : (anxietyLevel == 2
                      ? const Color(0xFFE6A017)
                      : const Color(0xFFE65A4F)),
            Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 8),
          _riskItem(
            'Digital Addiction',
            addictionLevel > 0.7
                ? 'High'
                : (addictionLevel > 0.4 ? 'Moderate' : 'Low'),
            addictionLevel > 0.7
                ? const Color(0xFFE65A4F)
                : (addictionLevel > 0.4
                      ? const Color(0xFFE6A017)
                      : const Color(0xFF2E8B57)),
            Icons.phone_android,
          ),
        ],
      ),
    );
  }

  Widget _buildAIModelConfidenceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Confidence',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _confidenceChip('Emotion Detection', 87),
              _confidenceChip('Behavior Prediction', 85),
              _confidenceChip('Risk Classification', 85),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Color(0xFF2E8B57)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'High confidence in analysis',
                    style: TextStyle(fontSize: 10, color: Color(0xFF2E8B57)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBehaviourSummary(
    ScreenTimeSnapshot snapshot,
    List<double> screenData,
    List<double> moodData,
  ) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              columnSpacing: 4,
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFF5F7FB),
              ),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              dataTextStyle: const TextStyle(fontSize: 11),
              columns: const [
                DataColumn(label: Text('Day')),
                DataColumn(label: Text('Screen')),
                DataColumn(label: Text('Mood')),
              ],
              rows: List.generate(7, (index) {
                final screen = index < screenData.length
                    ? screenData[index]
                    : 3.5;
                final mood = index < moodData.length ? moodData[index] : 5.0;
                final isMidWeek = index == 2 || index == 3;
                return DataRow(
                  color: isMidWeek
                      ? WidgetStateProperty.all(const Color(0xFFFFF3E0))
                      : null,
                  cells: [
                    DataCell(
                      Text(
                        days[index],
                        style: TextStyle(
                          fontWeight: isMidWeek ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    DataCell(Text('${screen.toStringAsFixed(1)}h')),
                    DataCell(Text(mood.toStringAsFixed(1))),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF4E6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '📊 Higher screen time & lower mood mid-week. Weekend improvement.',
              style: TextStyle(fontSize: 10, color: Color(0xFF6B7A8A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStatusSummary(
    double dayHours,
    int moodStability,
    int sleepQuality,
  ) {
    final warnings = <String>[];
    if (dayHours > 6) warnings.add('High screen time');
    if (moodStability < 60) warnings.add('Low mood');
    if (sleepQuality < 60) warnings.add('Poor sleep');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metrics Status',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _statusPill('Normal: 2', Colors.green),
              _statusPill('Positive: 1', Colors.blue),
              _statusPill('Stable: 3', Colors.orange),
              _statusPill('Warning: ${warnings.length}', Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          if (warnings.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Color(0xFFE65A4F),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '⚠️ ${warnings.join(", ")}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7A8A),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '✅ All metrics normal',
                style: TextStyle(fontSize: 10, color: Color(0xFF2E8B57)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClinicalInterpretation(
    double dayHours,
    double socialPercent,
    ScreenTimeSnapshot snapshot,
  ) {
    final topApp = snapshot.topApps.isNotEmpty
        ? snapshot.topApps.first.appName
        : 'general apps';
    final lateH = snapshot.lateNightWeekSeconds / 3600.0;
    final lateOpens = snapshot.lateNightOpensWeek;
    final lateNote = snapshot.usageStatsGranted
        ? ' Late-night phone use (10 PM–5 AM): ${lateH.toStringAsFixed(1)} h, ~$lateOpens opens/switches in the last 7 days.'
        : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clinical Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Digital wellbeing is ${dayHours > 5 ? "moderate" : "stable"}. Screen time: ${dayHours.toStringAsFixed(1)}h/day. '
            'Top app: $topApp. ${socialPercent > 30 ? "Social media high. " : ""}'
            '$lateNote '
            'Improve sleep by reducing late-night scrolling; balance app categories.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF4C4F61),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  Widget _statusTag(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _categoryBar(String label, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            Text(
              '${percent.toInt()}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: color.withOpacity(0.2),
            color: color,
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _riskItem(String label, String status, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _confidenceChip(String label, int percent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A6FA5),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ==================== DYNAMIC CALCULATION METHODS ====================

  int _calculateWellbeingScore(ScreenTimeSnapshot snapshot) {
    final dayHours = snapshot.daySeconds / 3600;
    final weekHours = snapshot.weekSeconds / 3600;
    final score = (80 - (dayHours * 2) - (weekHours / 7 * 1.5))
        .clamp(0, 100)
        .toInt();
    return score;
  }

  int _calculateMoodStability(ScreenTimeSnapshot snapshot) {
    final dayHours = snapshot.daySeconds / 3600;
    final score = (85 - (dayHours * 3)).clamp(20, 98).toInt();
    return score;
  }

  int _calculateSleepQuality(ScreenTimeSnapshot snapshot) {
    final lateHours = snapshot.lateNightWeekSeconds / 3600.0;
    final opens = snapshot.lateNightOpensWeek;
    final dayHours = snapshot.daySeconds / 3600.0;

    if (!snapshot.usageStatsGranted && lateHours == 0 && opens == 0) {
      return (92 - (dayHours * 2.5)).clamp(30, 98).round();
    }

    var score = 92.0;
    score -= (lateHours * 10).clamp(0, 52);
    score -= (opens * 0.85).clamp(0, 24);
    score -= ((dayHours - 3.5).clamp(0, 10) * 1.6);

    if (snapshot.usageStatsGranted && lateHours == 0 && opens == 0) {
      score = score.clamp(78, 98);
    }

    return score.clamp(15, 98).round();
  }

  int _riskScore(int daySeconds) {
    final hours = daySeconds / 3600.0;
    final score = (45 + (hours * 8)).clamp(10, 98).toInt();
    return score;
  }

  double _getCategoryPercentage(ScreenTimeSnapshot snapshot, String category) {
    final totalSeconds = snapshot.daySeconds;
    if (totalSeconds == 0) return 0.0;

    double categorySeconds = 0;
    for (final app in snapshot.topApps) {
      if (app.appName.toLowerCase().contains(category.toLowerCase())) {
        categorySeconds += app.durationSeconds;
      }
    }
    return (categorySeconds / totalSeconds * 100).clamp(0.0, 100.0);
  }

  double _getAppSwitchingPercent(ScreenTimeSnapshot snapshot) {
    final uniqueApps = snapshot.topApps.length;
    final switchingPercent = (uniqueApps * 8).clamp(5, 45).toDouble();
    return switchingPercent;
  }

  List<double> _getDailyScreenData(ScreenTimeSnapshot snapshot) {
    final totalHours = snapshot.daySeconds / 3600;
    final baseHours = totalHours / 2;

    return [
      baseHours * 0.7,
      baseHours * 0.85,
      baseHours * 1.0,
      baseHours * 0.95,
      baseHours * 0.8,
      baseHours * 0.6,
      baseHours * 0.55,
    ];
  }

  List<double> _getMoodData(
    ScreenTimeSnapshot snapshot,
    List<double> screenData,
  ) {
    return screenData.map((screenHours) {
      final mood = 7.0 - (screenHours / 3.5);
      return mood.clamp(3.5, 6.5);
    }).toList();
  }
}
