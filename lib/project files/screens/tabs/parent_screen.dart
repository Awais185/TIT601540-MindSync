import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../pages/profile_screen.dart';
import '../../services/parental_control_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/plan_access_service.dart';
import '../../ui/components/mind_sync_header.dart';
import '../../ui/layout/mindsync_layout.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final _parentService = ParentalControlService();
  final _auth = LocalAuthService();
  bool _loadingApps = false;
  bool _loadingUser = false;
  String _displayName = 'User';
  String? _faceImageUrl;
  int _socialLimitMinutes = 90;
  int _gamingLimitMinutes = 60;
  int _entertainmentLimitMinutes = 120;
  List<ParentalAppRule> _rules = const [];
  final Map<String, int> _appSocialLimits = {};

  // Content Time Restrictions switches
  bool socialMediaLimit = true;
  bool gamingLimit = true;
  bool entertainmentLimit = false;

  // App Restrictions switches
  bool tiktokLimit = true;
  bool youtubeLimit = true;
  bool robloxLimit = false;
  bool instagramLimit = true;

  // Safety Controls switches
  bool safeSearchActive = true;
  bool blockAdultContent = true;

  @override
  void initState() {
    super.initState();
    _initWithPlanCheck();
  }

  Future<void> _initWithPlanCheck() async {
    final allowed = await PlanAccessService.instance.canAccess('parental_control');
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgrade to Premium to access Parental Control.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
      return;
    }
    _loadUser();
    _loadParentRules();
    _applyPolicy();
  }

  Future<void> _loadUser() async {
    setState(() => _loadingUser = true);
    final profile = await _auth.fetchCurrentUserProfile();
    if (!mounted) return;
    setState(() {
      _displayName = profile?.fullName.isNotEmpty == true
          ? profile!.fullName
          : (profile?.displayName ?? 'User');
      _faceImageUrl = profile?.faceImage;
      _loadingUser = false;
    });
  }

  Future<void> _loadParentRules() async {
    setState(() => _loadingApps = true);
    final rules = await _parentService.fetchRules();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      for (final rule in rules) {
        _appSocialLimits.putIfAbsent(
          rule.packageName,
          () => _socialLimitMinutes,
        );
      }
      _loadingApps = false;
    });
  }

  Future<void> _toggleApp(String packageName, bool blocked) async {
    final previousRules = _rules;
    setState(() {
      _rules = _rules
          .map(
            (r) => r.packageName == packageName
                ? ParentalAppRule(
                    packageName: r.packageName,
                    appLabel: r.appLabel,
                    blocked: blocked,
                  )
                : r,
          )
          .toList();
    });

    final ok = await _parentService.setBlocked(
      packageName: packageName,
      blocked: blocked,
    );
    if (!ok) {
      if (!mounted) return;
      setState(() => _rules = previousRules);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update app block setting.')),
      );
      return;
    }
    await _loadParentRules();
  }

  Future<void> _applyPolicy() async {
    await _parentService.applyLocalPolicy(
      socialMinutesLimit: socialMediaLimit ? _socialLimitMinutes : 999999,
      gamingMinutesLimit: gamingLimit ? _gamingLimitMinutes : 999999,
      entertainmentMinutesLimit: entertainmentLimit
          ? _entertainmentLimitMinutes
          : 999999,
    );
  }

  Future<void> _changeLimit({
    required String title,
    required int current,
    required ValueChanged<int> onSave,
  }) async {
    final controller = TextEditingController(text: current.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title Limit (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter minutes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    onSave(value);
    await _applyPolicy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
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
              profileAvatarImageUrl: _faceImageUrl,
            ),
            const SizedBox(height: 16),

            // LIVE PROTECTION label
            const Text(
              'LIVE PROTECTION',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: Color(0xFFA1A1AA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            // Title
            const Text(
              'Parent Control',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: Color(0xFF18181B),
              ),
            ),
            const SizedBox(height: 14),

            // User Strip
            _UserStrip(userName: _loadingUser ? 'Loading...' : _displayName),
            const SizedBox(height: 20),

            // Usage Health Card
            const _UsageHealthCard(),
            const SizedBox(height: 20),

            // Content Monitor Card
            const _ContentMonitorCard(),
            const SizedBox(height: 20),

            // Content Time Restrictions Card
            _ContentTimeCard(
              socialMediaLimit: socialMediaLimit,
              gamingLimit: gamingLimit,
              entertainmentLimit: entertainmentLimit,
              socialLimitMinutes: _socialLimitMinutes,
              gamingLimitMinutes: _gamingLimitMinutes,
              entertainmentLimitMinutes: _entertainmentLimitMinutes,
              onChangeSocialLimit: () => _changeLimit(
                title: 'Social Media',
                current: _socialLimitMinutes,
                onSave: (v) => setState(() => _socialLimitMinutes = v),
              ),
              onChangeGamingLimit: () => _changeLimit(
                title: 'Gaming',
                current: _gamingLimitMinutes,
                onSave: (v) => setState(() => _gamingLimitMinutes = v),
              ),
              onChangeEntertainmentLimit: () => _changeLimit(
                title: 'Entertainment',
                current: _entertainmentLimitMinutes,
                onSave: (v) => setState(() => _entertainmentLimitMinutes = v),
              ),
              onSocialChanged: (val) => setState(() => socialMediaLimit = val),
              onGamingChanged: (val) => setState(() => gamingLimit = val),
              onEntertainmentChanged: (val) =>
                  setState(() => entertainmentLimit = val),
              onAfterToggleChanged: _applyPolicy,
            ),
            const SizedBox(height: 20),

            // App Restrictions Card
            _AppRestrictionsCard(
              loading: _loadingApps,
              rules: _rules,
              onRuleChanged: _toggleApp,
              appLimits: _appSocialLimits,
              onEditLimit: (rule) => _changeLimit(
                title: rule.appLabel,
                current:
                    _appSocialLimits[rule.packageName] ?? _socialLimitMinutes,
                onSave: (v) {
                  setState(() {
                    _appSocialLimits[rule.packageName] = v;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Safety Controls Card
            _SafetyControlsCard(
              safeSearchActive: safeSearchActive,
              blockAdultContent: blockAdultContent,
              onSafeSearchChanged: (val) =>
                  setState(() => safeSearchActive = val),
              onAdultBlockChanged: (val) =>
                  setState(() => blockAdultContent = val),
            ),
          ],
        ),
      ),
    );
  }
}

// User Strip Widget
class _UserStrip extends StatelessWidget {
  const _UserStrip({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE8D8CA),
            child: Icon(Icons.person, size: 16, color: Color(0xFF7A5036)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF18181B),
                ),
              ),
              const SizedBox(height: 2),
              const Row(
                children: [
                  Icon(Icons.circle, size: 6, color: Color(0xFF22C55E)),
                  SizedBox(width: 4),
                  Text(
                    'Online Now',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF71717A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Usage Health Card with Ring
class _UsageHealthCard extends StatelessWidget {
  const _UsageHealthCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          SizedBox(
            height: 152,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(152, 152),
                  painter: _UsageRingPainter(),
                ),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '2h 45m',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF18181B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'OF 4H LIMIT',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: Color(0xFFA1A1AA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Usage Health',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF18181B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Leo is 68% through his daily allowance.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFA1A1AA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;

    // Background track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = const Color(0xFFEFF0F5)
      ..strokeCap = StrokeCap.round;

    // Progress arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = const Color(0xFF8B5CF6)
      ..strokeCap = StrokeCap.round;

    // Draw background circle (almost full)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.8,
      5.2,
      false,
      trackPaint,
    );

    // Draw progress (68% = ~3.5 radians)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.8,
      3.5,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Content Monitor Card
class _ContentMonitorCard extends StatelessWidget {
  const _ContentMonitorCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                'Content Monitor',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF18181B),
                ),
              ),
              Spacer(),
              Icon(Icons.monitor_heart, size: 18, color: Color(0xFF14B8A6)),
            ],
          ),
          const SizedBox(height: 16),
          const _MonitorBar(
            label: 'Education',
            value: '45%',
            progress: 0.45,
            color: Color(0xFF14B8A6),
          ),
          const SizedBox(height: 12),
          const _MonitorBar(
            label: 'Social Media',
            value: '30%',
            progress: 0.30,
            color: Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          const _MonitorBar(
            label: 'Gaming',
            value: '20%',
            progress: 0.20,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: _AlertBadge(text: 'Adult Risk Blocked')),
              SizedBox(width: 10),
              Expanded(child: _AlertBadge(text: 'Violent Content Blocked')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonitorBar extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _MonitorBar({
    required this.label,
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F3F46),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF52525B),
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
            backgroundColor: const Color(0xFFEFF0F5),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _AlertBadge extends StatelessWidget {
  final String text;
  const _AlertBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Content Time Restrictions Card
class _ContentTimeCard extends StatelessWidget {
  final bool socialMediaLimit;
  final bool gamingLimit;
  final bool entertainmentLimit;
  final int socialLimitMinutes;
  final int gamingLimitMinutes;
  final int entertainmentLimitMinutes;
  final VoidCallback onChangeSocialLimit;
  final VoidCallback onChangeGamingLimit;
  final VoidCallback onChangeEntertainmentLimit;
  final ValueChanged<bool> onSocialChanged;
  final ValueChanged<bool> onGamingChanged;
  final ValueChanged<bool> onEntertainmentChanged;
  final Future<void> Function() onAfterToggleChanged;

  const _ContentTimeCard({
    required this.socialMediaLimit,
    required this.gamingLimit,
    required this.entertainmentLimit,
    required this.socialLimitMinutes,
    required this.gamingLimitMinutes,
    required this.entertainmentLimitMinutes,
    required this.onChangeSocialLimit,
    required this.onChangeGamingLimit,
    required this.onChangeEntertainmentLimit,
    required this.onSocialChanged,
    required this.onGamingChanged,
    required this.onEntertainmentChanged,
    required this.onAfterToggleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            'Content\nRestrictions',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: Color(0xFF18181B),
            ),
          ),
          const SizedBox(height: 18),
          _RestrictionRow(
            icon: Icons.people,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF8B5CF6),
            title: 'Social Media',
            subtitle: 'Limit: ${_formatMinutes(socialLimitMinutes)}',
            value: socialMediaLimit,
            onChanged: (v) {
              onSocialChanged(v);
              onAfterToggleChanged();
            },
            onSubtitleTap: onChangeSocialLimit,
          ),
          const SizedBox(height: 14),
          _RestrictionRow(
            icon: Icons.sports_esports,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF3B82F6),
            title: 'Gaming',
            subtitle: 'Limit: ${_formatMinutes(gamingLimitMinutes)}',
            value: gamingLimit,
            onChanged: (v) {
              onGamingChanged(v);
              onAfterToggleChanged();
            },
            onSubtitleTap: onChangeGamingLimit,
          ),
          const SizedBox(height: 14),
          _RestrictionRow(
            icon: Icons.movie,
            iconBg: const Color(0xFFF0FDFA),
            iconColor: const Color(0xFF14B8A6),
            title: 'Entertainment',
            subtitle: 'Limit: ${_formatMinutes(entertainmentLimitMinutes)}',
            value: entertainmentLimit,
            onChanged: (v) {
              onEntertainmentChanged(v);
              onAfterToggleChanged();
            },
            onSubtitleTap: onChangeEntertainmentLimit,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onChangeSocialLimit,
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: Text(
                'Set Social Media Limit (${_formatMinutes(socialLimitMinutes)})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// App Restrictions Card
class _AppRestrictionsCard extends StatelessWidget {
  final bool loading;
  final List<ParentalAppRule> rules;
  final Future<void> Function(String packageName, bool blocked) onRuleChanged;
  final Map<String, int> appLimits;
  final Future<void> Function(ParentalAppRule rule) onEditLimit;

  const _AppRestrictionsCard({
    required this.loading,
    required this.rules,
    required this.onRuleChanged,
    required this.appLimits,
    required this.onEditLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                'App Restrictions',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF18181B),
                ),
              ),
              Spacer(),
              Text(
                'View All +',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            ...rules.take(10).map((rule) {
              final icon = _iconForPackage(rule.packageName, rule.appLabel);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AppRestrictionRow(
                  icon: icon.icon,
                  iconBg: icon.iconBg,
                  iconColor: icon.iconColor,
                  iconIsBrand: icon.isBrand,
                  title: rule.appLabel,
                  subtitle:
                      'Limit: ${_formatMinutes(appLimits[rule.packageName] ?? 0)}  •  ${rule.packageName}',
                  value: rule.blocked,
                  onChanged: (val) => onRuleChanged(rule.packageName, val),
                  onEditLimit: () => onEditLimit(rule),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// Safety Controls Card
class _SafetyControlsCard extends StatelessWidget {
  final bool safeSearchActive;
  final bool blockAdultContent;
  final ValueChanged<bool> onSafeSearchChanged;
  final ValueChanged<bool> onAdultBlockChanged;

  const _SafetyControlsCard({
    required this.safeSearchActive,
    required this.blockAdultContent,
    required this.onSafeSearchChanged,
    required this.onAdultBlockChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            'Safety Controls',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF18181B),
            ),
          ),
          const SizedBox(height: 18),
          _SafetyRow(
            icon: Icons.search,
            iconBg: const Color(0xFFF0FDFA),
            iconColor: const Color(0xFF14B8A6),
            title: 'SafeSearch Active',
            subtitle: 'Filters explicit searches results',
            value: safeSearchActive,
            onChanged: onSafeSearchChanged,
          ),
          const SizedBox(height: 14),
          _SafetyRow(
            icon: Icons.block,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF8B5CF6),
            title: 'Block Adult Content',
            subtitle: 'System-wide web filtering',
            value: blockAdultContent,
            onChanged: onAdultBlockChanged,
          ),
        ],
      ),
    );
  }
}

// Reusable Restriction Row
class _RestrictionRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onSubtitleTap;

  const _RestrictionRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onSubtitleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF18181B),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: onSubtitleTap,
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF71717A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 1,
          child: _BlockToggleButton(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

class _AppIconStyle {
  const _AppIconStyle(
    this.icon,
    this.iconBg,
    this.iconColor, {
    this.isBrand = false,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool isBrand;
}

_AppIconStyle _iconForPackage(String packageName, String appLabel) {
  final v = '$packageName ${appLabel.toLowerCase()}';
  if (v.contains('instagram')) {
    return const _AppIconStyle(
      FontAwesomeIcons.instagram,
      Color(0xFFFFEFFB),
      Color(0xFFB649A9),
      isBrand: true,
    );
  }
  if (v.contains('youtube')) {
    return const _AppIconStyle(
      FontAwesomeIcons.youtube,
      Color(0xFFFEF2F2),
      Color(0xFFEF4444),
      isBrand: true,
    );
  }
  if (v.contains('tiktok') || v.contains('musically') || v.contains('trill')) {
    return const _AppIconStyle(
      FontAwesomeIcons.tiktok,
      Color(0xFF1B1B1B),
      Colors.white,
      isBrand: true,
    );
  }
  if (v.contains('whatsapp')) {
    return const _AppIconStyle(
      FontAwesomeIcons.whatsapp,
      Color(0xFFEAF9EF),
      Color(0xFF25D366),
      isBrand: true,
    );
  }
  if (v.contains('snapchat')) {
    return const _AppIconStyle(
      FontAwesomeIcons.snapchat,
      Color(0xFFFFF9C4),
      Color(0xFFEFB700),
      isBrand: true,
    );
  }
  if (v.contains('facebook')) {
    return const _AppIconStyle(
      FontAwesomeIcons.facebook,
      Color(0xFFEAF0FF),
      Color(0xFF1877F2),
      isBrand: true,
    );
  }
  if (v.contains('twitter') || v.contains('x')) {
    return const _AppIconStyle(
      FontAwesomeIcons.xTwitter,
      Color(0xFFF2F2F2),
      Color(0xFF111111),
      isBrand: true,
    );
  }
  if (v.contains('discord')) {
    return const _AppIconStyle(
      Icons.forum_rounded,
      Color(0xFFF1F2FF),
      Color(0xFF5563D4),
    );
  }
  return const _AppIconStyle(
    Icons.apps_rounded,
    Color(0xFFF1F3F8),
    Color(0xFF5A5E6C),
  );
}

// App Restriction Row with limit text
class _AppRestrictionRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool iconIsBrand;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEditLimit;

  const _AppRestrictionRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.iconIsBrand = false,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.onEditLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: iconIsBrand
                ? FaIcon(icon, size: 16, color: iconColor)
                : Icon(icon, size: 18, color: iconColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF18181B),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: onEditLimit,
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF71717A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        _BlockToggleButton(value: value, onChanged: onChanged),
      ],
    );
  }
}

// Safety Row
class _SafetyRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SafetyRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF18181B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF71717A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _BlockToggleButton(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _BlockToggleButton extends StatelessWidget {
  const _BlockToggleButton({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isBlocked = value;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isBlocked ? const Color(0xFFFEF2F2) : const Color(0xFF8B5CF6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isBlocked
                ? const Color(0xFFFCA5A5)
                : const Color(0xFF8B5CF6),
          ),
        ),
        child: Text(
          isBlocked ? 'Unblock' : 'Block',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isBlocked ? const Color(0xFFB91C1C) : Colors.white,
          ),
        ),
      ),
    );
  }
}

// Bottom Navigation Bar
