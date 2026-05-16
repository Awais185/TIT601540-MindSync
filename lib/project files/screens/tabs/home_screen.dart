import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../route_observers.dart';
import '../pages/profile_screen.dart';
import '../../services/app_public_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/screen_time_service.dart';
import '../../services/tracking_permissions_gate.dart';
import '../../services/wellness_dashboard_service.dart';
import '../../widgets/mindsync_logo.dart';

Uint8List? _decodeAppIconBase64(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return Uint8List.fromList(base64Decode(b64));
  } catch (_) {
    return null;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final _auth = LocalAuthService();
  String _displayName = 'User';

  @override
  void initState() {
    super.initState();
    unawaited(TrackingPermissionsGate.startScreenTimeIfPermitted());
    unawaited(ScreenTimeService.instance.refreshRollingAppUsage());
    unawaited(WellnessDashboardService.instance.refresh(force: true));
    AppPublicService.instance.loadBranding(forceRefresh: false);
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    mindSyncRouteObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      mindSyncRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    mindSyncRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    unawaited(ScreenTimeService.instance.refreshRollingAppUsage());
  }

  @override
  void didPopNext() {
    unawaited(ScreenTimeService.instance.refreshRollingAppUsage());
  }

  Future<void> _loadProfile() async {
    final profile = await _auth.fetchCurrentUserProfile();
    if (!mounted || profile == null) return;
    setState(() => _displayName = profile.displayName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            _TopOverviewCard(
              userName: _displayName,
              onProfileTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            const _MetricGrid(),
            const SizedBox(height: 16),
            const _AppUsageCard(),
            const SizedBox(height: 16),
            const _VulnerabilityCardDynamic(),
            const SizedBox(height: 16),
            const _WeeklyMoodCardDynamic(),
          ],
        ),
      ),
    );
  }
}

class _TopOverviewCard extends StatefulWidget {
  const _TopOverviewCard({required this.onProfileTap, required this.userName});

  final VoidCallback onProfileTap;
  final String userName;

  @override
  State<_TopOverviewCard> createState() => _TopOverviewCardState();
}

class _TopOverviewCardState extends State<_TopOverviewCard> {
  @override
  void initState() {
    super.initState();
    AppPublicService.instance.loadBranding(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 174, 128, 228),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with MindSync logo and profile icon
          Row(
            children: [
              const SizedBox(
                height: 88,
                width: 150,
                child: MindSyncLogo(height: 82, width: 140),
              ),
              const Spacer(),
              InkWell(
                onTap: widget.onProfileTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE0E0E8),
                      width: 1.5,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFF0F0F5),
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF6B6C76),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Hello user greeting
          Text(
            'Hello, ${widget.userName}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 250, 251, 252),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          // Restorative phase message
          const Text(
            'MindSync - Because your mental health matters',
            style: TextStyle(
              fontSize: 15,
              color: Color.fromARGB(255, 250, 250, 250),
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: _WellbeingScoreCardLive()),
            SizedBox(width: 12),
            Expanded(child: _ScreenTimeCard()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: _StressLevelCardLive()),
            SizedBox(width: 12),
            Expanded(child: _ActionNeededCard()),
          ],
        ),
      ],
    );
  }
}

class _WellbeingScoreCardLive extends StatelessWidget {
  const _WellbeingScoreCardLive();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<WellnessDashboardData>(
        valueListenable: WellnessDashboardService.instance.dashboard,
        builder: (context, d, _) {
          final score = d.wellbeingScore.clamp(0, 100);
          final mental = d.mentalHealthScore.clamp(0, 100);
          final progress = (score / 100.0).clamp(0.001, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle_outlined, size: 14, color: Color(0xFF6F39E8)),
              const SizedBox(height: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3.5,
                      backgroundColor: const Color(0xFFE7E8EF),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6F39E8)),
                    ),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF1A2130),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MH $mental',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B6E7A),
                ),
              ),
              const Spacer(),
              const Text(
                'WELLBEING SCORE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Color(0xFF8A8D99),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScreenTimeCard extends StatelessWidget {
  const _ScreenTimeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF6F39E8)),
              const Spacer(),
              ValueListenableBuilder<ScreenTimeSnapshot>(
                valueListenable: ScreenTimeService.instance.snapshot,
                builder: (_, data, _) {
                  final liveBadge = data.usageStatsGranted;
                  return Text(
                    liveBadge ? 'Live' : '—',
                    style: TextStyle(
                      fontSize: 11,
                      color: liveBadge
                          ? const Color(0xFF0E9186)
                          : const Color(0xFF8A8D99),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<int>(
            valueListenable: ScreenTimeService.instance.sessionDisplaySeconds,
            builder: (_, sessionSecs, _) {
              return ValueListenableBuilder<int>(
                valueListenable: ScreenTimeService.instance.todayLiveDisplaySeconds,
                builder: (_, live, _) {
                  return ValueListenableBuilder<ScreenTimeSnapshot>(
                    valueListenable: ScreenTimeService.instance.snapshot,
                    builder: (_, data, _) {
                      final secs = data.nativeTrackerConfigured
                          ? sessionSecs
                          : (data.usageStatsGranted ? live : data.daySeconds);
                      return Text(
                        formatDurationClock(secs),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 0.95,
                          color: Color(0xFF1A2130),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 32,
              height: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 5,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F39E8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 5,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7CD8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'SCREEN TIME',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: Color(0xFF8A8D99),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StressLevelCardLive extends StatelessWidget {
  const _StressLevelCardLive();

  static String _label(int stress) {
    if (stress >= 67) return 'High';
    if (stress >= 34) return 'Medium';
    if (stress > 0) return 'Elevated';
    return 'Stable';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<WellnessDashboardData>(
        valueListenable: WellnessDashboardService.instance.dashboard,
        builder: (context, d, _) {
          final stress = d.stressIndicator.clamp(0, 100);
          final frac = stress / 100.0;
          final barColor = stress >= 60
              ? const Color(0xFFE06C80)
              : stress >= 30
                  ? const Color(0xFFE09100)
                  : const Color(0xFF15B5A7);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                size: 14,
                color: Color(0xFF6F39E8),
              ),
              const SizedBox(height: 8),
              Text(
                _label(stress),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                  color: Color(0xFF1A2130),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$stress% signal · 7d clips',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A8D99),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: math.min(120.0, 36.0 + 80.0 * frac),
                height: 4,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Spacer(),
              const Text(
                'STRESS LEVEL',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Color(0xFF8A8D99),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionNeededCard extends StatelessWidget {
  const _ActionNeededCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<ScreenTimeSnapshot>(
        valueListenable: ScreenTimeService.instance.snapshot,
        builder: (context, data, _) {
          final monitoringOn =
              data.usageStatsGranted && data.nativeTrackerConfigured;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                monitoringOn
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_rounded,
                size: 14,
                color: const Color(0xFF6F39E8),
              ),
              const SizedBox(height: 8),
              Text(
                monitoringOn ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                  color: monitoringOn
                      ? const Color(0xFF1A2130)
                      : const Color(0xFFB85C00),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Monitoring',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A8D99),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!monitoringOn)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await ScreenTimeService.instance.openUsageSettings();
                    await ScreenTimeService.instance.refreshNow();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Open usage settings',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6F39E8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else if (!data.screenCaptureGranted)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await ScreenTimeService.instance
                        .ensureScreenCapturePermission();
                    await ScreenTimeService.instance.refreshNow();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Optional: screen capture',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6F39E8),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              const Text(
                'ALERTS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Color(0xFF8A8D99),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppUsageCard extends StatelessWidget {
  const _AppUsageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          ScreenTimeService.instance.snapshot,
          ScreenTimeService.instance.rollingAppUsage,
        ]),
        builder: (context, _) {
          final data = ScreenTimeService.instance.snapshot.value;
          final rolling = ScreenTimeService.instance.rollingAppUsage.value;
          final fgName = data.foregroundAppName.trim();
          final fgPkg = data.foregroundPackage.trim();

          final useRolling = data.usageStatsGranted && rolling.isNotEmpty;
          var ranked = List<AppUsageItem>.from(
            useRolling ? rolling : data.topApps,
          )..sort((a, b) => b.sortKeyMs.compareTo(a.sortKeyMs));

          final shown = <AppUsageItem>[];
          if (fgName.isNotEmpty && fgPkg.isNotEmpty) {
            AppUsageItem? match;
            for (final a in ranked) {
              if (a.packageName == fgPkg) {
                match = a;
                break;
              }
            }
            shown.add(
              match ??
                  AppUsageItem(
                    packageName: fgPkg,
                    appName: fgName,
                    durationSeconds: data.foregroundAppTodaySeconds,
                    totalForegroundMs: data.foregroundAppTodaySeconds * 1000,
                    iconPngBase64: data.foregroundIconPngBase64.isEmpty
                        ? null
                        : data.foregroundIconPngBase64,
                  ),
            );
          }
          for (final a in ranked) {
            if (shown.length >= 5) break;
            if (fgPkg.isNotEmpty && a.packageName == fgPkg) continue;
            shown.add(a);
          }

          final maxMs = shown.isEmpty
              ? 1
              : shown.map((e) => e.sortKeyMs).reduce((a, b) => a > b ? a : b);

          return Column(
            children: [
              Row(
                children: [
                  const Text(
                    'App Usage',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2130),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8C8C96),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                const Text(
                  'Usage data will appear after you use other apps today. '
                  'Ensure Usage Access is enabled.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A7D8A)),
                )
              else
                ...shown.asMap().entries.map((entry) {
                  final app = entry.value;
                  final style = _styleForApp(app.appName);
                  final bytes = _decodeAppIconBase64(app.iconPngBase64);
                  final isFg =
                      fgPkg.isNotEmpty && app.packageName == fgPkg;
                  final displaySecs = (app.sortKeyMs / 1000).round();
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == shown.length - 1 ? 0 : 14,
                    ),
                    child: _UsageRow(
                      label: app.appName,
                      time: formatDurationShort(displaySecs),
                      progress: app.sortKeyMs / maxMs,
                      color: style.color,
                      icon: style.icon,
                      iconBg: style.iconBg,
                      iconColor: style.iconColor,
                      iconBitmap: bytes,
                      showLiveBadge: isFg,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _AppVisualStyle {
  const _AppVisualStyle({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.color,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color color;
}

_AppVisualStyle _styleForApp(String appName) {
  final lower = appName.toLowerCase();
  if (lower.contains('tiktok')) {
    return const _AppVisualStyle(
      icon: Icons.music_note_rounded,
      iconBg: Color(0xFFFFEEF3),
      iconColor: Color(0xFFCE4960),
      color: Color(0xFFE06C80),
    );
  }
  if (lower.contains('youtube')) {
    return const _AppVisualStyle(
      icon: Icons.play_circle_fill_rounded,
      iconBg: Color(0xFFFFF1F1),
      iconColor: Color(0xFFDA3F4A),
      color: Color(0xFFD95A6A),
    );
  }
  if (lower.contains('discord')) {
    return const _AppVisualStyle(
      icon: Icons.forum_rounded,
      iconBg: Color(0xFFF1F2FF),
      iconColor: Color(0xFF5563D4),
      color: Color(0xFF626ED7),
    );
  }
  if (lower.contains('instagram')) {
    return const _AppVisualStyle(
      icon: Icons.camera_alt_rounded,
      iconBg: Color(0xFFFFEFFB),
      iconColor: Color(0xFFB649A9),
      color: Color(0xFFC956C2),
    );
  }
  return const _AppVisualStyle(
    icon: Icons.apps_rounded,
    iconBg: Color(0xFFF1F3F8),
    iconColor: Color(0xFF5A5E6C),
    color: Color(0xFF7A80A0),
  );
}

class _UsageRow extends StatelessWidget {
  final String label;
  final String time;
  final double progress;
  final Color color;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Uint8List? iconBitmap;
  final bool showLiveBadge;

  const _UsageRow({
    required this.label,
    required this.time,
    required this.progress,
    required this.color,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.iconBitmap,
    this.showLiveBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: iconBitmap != null && iconBitmap!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        iconBitmap!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  : Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  if (showLiveBadge) ...[
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE53935),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2D36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              time,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B6C76),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: const Color(0xFFEFF0F5),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _VulnerabilityCardDynamic extends StatelessWidget {
  const _VulnerabilityCardDynamic();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<WellnessDashboardData>(
        valueListenable: WellnessDashboardService.instance.dashboard,
        builder: (context, d, _) {
          final s = d.stressIndicator.clamp(0, 100);
          final a = d.anxietyIndicator.clamp(0, 100);
          final dep = d.depressionIndicator.clamp(0, 100);
          final clipNote =
              '${d.totalChunks} clip${d.totalChunks == 1 ? '' : 's'} · last 7 days';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Mental Health Insights',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2130),
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF9A9BA6)),
                ],
              ),
              const SizedBox(height: 16),
              _VulnerabilityRow(
                label: 'Stress',
                sub: clipNote,
                value: '$s%',
                progress: (s / 100).clamp(0.0, 1.0),
                color: const Color(0xFF7E4AE7),
              ),
              const SizedBox(height: 12),
              _VulnerabilityRow(
                label: 'Anxiety',
                sub: 'From behaviour + content cues',
                value: '$a%',
                progress: (a / 100).clamp(0.0, 1.0),
                color: const Color(0xFF1EB4A8),
              ),
              const SizedBox(height: 12),
              _VulnerabilityRow(
                label: 'Depression',
                sub: 'Starts at 0 until patterns emerge',
                value: '$dep%',
                progress: (dep / 100).clamp(0.0, 1.0),
                color: const Color(0xFF2E6FD2),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VulnerabilityRow extends StatelessWidget {
  final String label;
  final String sub;
  final String value;
  final double progress;
  final Color color;

  const _VulnerabilityRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF2C2D36),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF385A76),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9EA0AA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFEFF0F5),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _WeeklyMoodCardDynamic extends StatelessWidget {
  const _WeeklyMoodCardDynamic();

  Widget _buildTag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64646F),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWeekLabels() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('MON', style: TextStyle(fontSize: 11, color: Color(0xFF8A8D99), fontWeight: FontWeight.w600)),
        Text('TUE', style: TextStyle(fontSize: 11, color: Color(0xFF8A8D99), fontWeight: FontWeight.w600)),
        Text('WED', style: TextStyle(fontSize: 11, color: Color(0xFF8A8D99), fontWeight: FontWeight.w600)),
        Text('THU', style: TextStyle(fontSize: 11, color: Color(0xFF8A8D99), fontWeight: FontWeight.w600)),
        Text('FRI', style: TextStyle(fontSize: 11, color: Color(0xFF8A8D99), fontWeight: FontWeight.w600)),
        Text('SAT', style: TextStyle(fontSize: 11, color: Color(0xFF8A8D99), fontWeight: FontWeight.w600)),
        Text('SUN', style: TextStyle(fontSize: 11, color: Color(0xFF8A8D99), fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<WellnessDashboardData>(
        valueListenable: WellnessDashboardService.instance.dashboard,
        builder: (context, d, _) {
          final dm = (d.dominantMoodWeek).toUpperCase();
          final totalSamples = d.moodLast7.fold<int>(0, (a, b) => a + (((b['samples'] ?? 0) as num?)?.toInt() ?? 0));
          final summary = totalSamples > 0
              ? '$totalSamples facial/content samples this week.'
              : 'Uploading screen clips fills this graph with real mood arcs.';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Mood Architecture',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Color(0xFF1A2130),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'DOMINANT: $dm',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF37B48A),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B6E7A),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTag(context, '7 Days'),
                  const SizedBox(width: 8),
                  _buildTag(context, 'Live refresh'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: _MoodGraphPainter(),
                  size: Size(MediaQuery.of(context).size.width - 60, 110),
                ),
              ),
              const SizedBox(height: 12),
              _buildWeekLabels(),
            ],
          );
        },
      ),
    );
  }
}

class _MoodGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFFF5F4FC)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    final fillPath = Path();
    fillPath.moveTo(0, size.height * 0.85);
    fillPath.cubicTo(
      size.width * 0.15,
      size.height * 0.65,
      size.width * 0.25,
      size.height * 0.95,
      size.width * 0.4,
      size.height * 0.55,
    );
    fillPath.cubicTo(
      size.width * 0.52,
      size.height * 0.25,
      size.width * 0.65,
      size.height * 0.9,
      size.width * 0.78,
      size.height * 0.42,
    );
    fillPath.cubicTo(
      size.width * 0.88,
      size.height * 0.12,
      size.width * 0.94,
      size.height * 0.28,
      size.width,
      size.height * 0.2,
    );
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = const Color(0xFFEAE5FA)
        ..style = PaintingStyle.fill,
    );

    final linePath = Path();
    linePath.moveTo(0, size.height * 0.85);
    linePath.cubicTo(
      size.width * 0.15,
      size.height * 0.65,
      size.width * 0.25,
      size.height * 0.95,
      size.width * 0.4,
      size.height * 0.55,
    );
    linePath.cubicTo(
      size.width * 0.52,
      size.height * 0.25,
      size.width * 0.65,
      size.height * 0.9,
      size.width * 0.78,
      size.height * 0.42,
    );
    linePath.cubicTo(
      size.width * 0.88,
      size.height * 0.12,
      size.width * 0.94,
      size.height * 0.28,
      size.width,
      size.height * 0.2,
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF6F39E8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final points = [
      Offset(0, size.height * 0.85),
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.25, size.height * 0.95),
      Offset(size.width * 0.4, size.height * 0.55),
      Offset(size.width * 0.52, size.height * 0.25),
      Offset(size.width * 0.65, size.height * 0.9),
      Offset(size.width * 0.78, size.height * 0.42),
      Offset(size.width * 0.88, size.height * 0.12),
      Offset(size.width * 0.94, size.height * 0.28),
      Offset(size.width, size.height * 0.2),
    ];

    for (var point in points) {
      canvas.drawCircle(
        point,
        3,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        3,
        Paint()
          ..color = const Color(0xFF6F39E8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
