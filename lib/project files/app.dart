import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'route_observers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/permission_onboarding_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/main_shell_screen.dart';
import 'services/app_public_service.dart';
import 'services/local_auth_service.dart';
import 'services/screen_time_service.dart';
import 'services/tracking_permission_prefs.dart';
import 'services/tracking_permissions_gate.dart';

class MindSyncScrollBehavior extends MaterialScrollBehavior {
  const MindSyncScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}

enum _LaunchTarget { splash, welcome, login, permissionSetup, main }

class MindSyncApp extends StatefulWidget {
  const MindSyncApp({super.key});

  @override
  State<MindSyncApp> createState() => _MindSyncAppState();
}

class _MindSyncAppState extends State<MindSyncApp> with WidgetsBindingObserver {
  static const _kOnboardingDone = 'mindsync.onboarding_complete';

  _LaunchTarget _target = _LaunchTarget.splash;
  final LocalAuthService _auth = LocalAuthService();
  AuthProfile? _pendingProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppPublicService.instance.loadBranding();
    AppPublicService.instance.loadSubscriptionPlans();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _target != _LaunchTarget.main) {
      return;
    }
    unawaited(_syncSessionAfterResume());
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(_kOnboardingDone) ?? false;

    final profile = await _auth.restoreSessionIfPossible();

    if (!mounted) return;

    if (profile != null) {
      if (!await TrackingPermissionsGate.isFullyGranted()) {
        _pendingProfile = profile;
        setState(() => _target = _LaunchTarget.permissionSetup);
        return;
      }
      await _applyAuthenticatedProfile(profile);
      setState(() => _target = _LaunchTarget.main);
      return;
    }

    setState(() {
      _target = onboardingDone ? _LaunchTarget.login : _LaunchTarget.welcome;
    });
  }

  Future<void> _applyAuthenticatedProfile(AuthProfile profile) async {
    try {
      await _auth.tryRefreshAccessToken();
    } catch (_) {
      // Offline / transient — keep local session and still enable tracking if permitted.
    }
    ScreenTimeService.instance.setFaceVerified(profile.faceEnrolled);
    ScreenTimeService.instance.setFaceMatchPercent(50);
    final userId = await _auth.getStoredUserId();
    await ScreenTimeService.instance.setTrackingUser(userId);
    await TrackingPermissionsGate.startScreenTimeIfPermitted();
    await ScreenTimeService.instance.flushMidnightScreenTimePending();
  }

  Future<void> _finishPermissionBootstrap(AuthProfile profile) async {
    await _applyAuthenticatedProfile(profile);
    if (!mounted) return;
    setState(() {
      _pendingProfile = null;
      _target = _LaunchTarget.main;
    });
  }

  Future<void> _abandonPermissionBootstrap() async {
    await _auth.logout();
    ScreenTimeService.instance.stop();
    await ScreenTimeService.instance.clearTrackingUser();
    ScreenTimeService.instance.setFaceVerified(false);
    if (!mounted) return;
    setState(() {
      _pendingProfile = null;
      _target = _LaunchTarget.login;
    });
  }

  Future<void> _syncSessionAfterResume() async {
    if (!await TrackingPermissionsGate.isFullyGranted()) {
      final setupDone = await TrackingPermissionPrefs.isSetupMarkedDone();
      if (setupDone) {
        final profile = await _auth.fetchCurrentUserProfile();
        if (!mounted) return;
        if (profile != null) {
          _pendingProfile = profile;
          setState(() => _target = _LaunchTarget.permissionSetup);
          return;
        }
      }
      await _auth.logout();
      ScreenTimeService.instance.stop();
      await ScreenTimeService.instance.clearTrackingUser();
      ScreenTimeService.instance.setFaceVerified(false);
      if (!mounted) return;
      setState(() => _target = _LaunchTarget.login);
      return;
    }
    try {
      await _auth.tryRefreshAccessToken();
    } catch (_) {}
    final profile = await _auth.fetchCurrentUserProfile();
    if (!mounted || profile == null) return;
    ScreenTimeService.instance.setFaceVerified(profile.faceEnrolled);
    ScreenTimeService.instance.setFaceMatchPercent(50);
    await ScreenTimeService.instance.setTrackingUser(await _auth.getStoredUserId());
    await TrackingPermissionsGate.startScreenTimeIfPermitted();
    await ScreenTimeService.instance.flushMidnightScreenTimePending();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
    if (mounted) {
      setState(() => _target = _LaunchTarget.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget home = const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );

    switch (_target) {
      case _LaunchTarget.splash:
        break;
      case _LaunchTarget.welcome:
        home = WelcomeScreen(
          onGetStarted: () {
            unawaited(_completeOnboarding());
          },
        );
        break;
      case _LaunchTarget.login:
        home = const LoginScreen();
        break;
      case _LaunchTarget.permissionSetup:
        home = PermissionOnboardingScreen(
          auth: _auth,
          embeddedInAppBootstrap: true,
          onBootstrapGranted: () {
            final p = _pendingProfile;
            if (p == null || !mounted) return;
            unawaited(_finishPermissionBootstrap(p));
          },
          onBootstrapAbandon: () {
            if (!mounted) return;
            unawaited(_abandonPermissionBootstrap());
          },
        );
        break;
      case _LaunchTarget.main:
        home = const MainShellScreen();
        break;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MindSync',
      navigatorObservers: [mindSyncRouteObserver],
      scrollBehavior: const MindSyncScrollBehavior(),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF6F6FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6F39E8)),
        fontFamily: 'Roboto',
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF1F2330),
          displayColor: const Color(0xFF1F2330),
        ),
        dividerColor: const Color(0xFFDADDE7),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
