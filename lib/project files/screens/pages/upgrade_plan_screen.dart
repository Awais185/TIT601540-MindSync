import 'package:flutter/material.dart';
import '../../services/app_public_service.dart';
import '../../services/subscription_service.dart';

class UpgradePlanScreen extends StatefulWidget {
  const UpgradePlanScreen({super.key});

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> {
  late final AppPublicService _publicService;
  late final SubscriptionService _subscriptionService;
  late Future<List<SubscriptionPlanModel>> _plansFuture;
  late Future<CurrentSubscriptionModel?> _currentFuture;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _publicService = AppPublicService.instance;
    _subscriptionService = SubscriptionService.instance;
    _plansFuture = _subscriptionService.getPlans();
    _currentFuture = _subscriptionService.getCurrentSubscription();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: FutureBuilder<List<SubscriptionPlanModel>>(
          future: _plansFuture,
          builder: (context, plansSnap) {
            final plans = (plansSnap.data ?? const <SubscriptionPlanModel>[])
                .where(
                  (p) =>
                      p.code.toLowerCase() == 'basic' ||
                      p.code.toLowerCase() == 'premium',
                )
                .toList();
            if (plans.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (selectedIndex >= plans.length) {
              selectedIndex = 0;
            }

            final selectedPlan = plans[selectedIndex];
            return FutureBuilder<CurrentSubscriptionModel?>(
              future: _currentFuture,
              builder: (context, currentSnap) {
                final current = currentSnap.data;
                final currentPlanCode = (current?.effectivePlanCode ?? 'free')
                    .toLowerCase();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Color(0xFF6E6F7A),
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<AppBrandingData>(
                      valueListenable: _publicService.branding,
                      builder: (context, branding, _) => Text(
                        branding.appName,
                        style: const TextStyle(
                          color: Color(0xFF6F39E8),
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 22),
                  ],
                ),
                const SizedBox(height: 24),

                // UNLOCK SYNERGY label
                const Text(
                  'UNLOCK SYNERGY',
                  style: TextStyle(
                    color: Color(0xFFA2A4AF),
                    letterSpacing: 1.5,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),

                // Title
                const Text(
                  'Choose your\njourney.',
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14151D),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Plan Tabs
                    _PlanTabs(
                      plans: plans,
                      selectedIndex: selectedIndex,
                      onChanged: (index) => setState(() => selectedIndex = index),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Current plan: ${current?.plan.name ?? 'Free'} • Status: ${(current?.status ?? 'inactive').toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B5E6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                // Plan Card
                    _PlanCard(
                      plan: selectedPlan,
                      currentPlanCode: currentPlanCode,
                      onBought: () {
                        setState(() {
                          _currentFuture =
                              _subscriptionService.getCurrentSubscription();
                          _plansFuture = _subscriptionService.getPlans();
                        });
                      },
                    ),
                    const SizedBox(height: 28),

                // Compare Benefits Section
                    const Text(
                      'Compare Benefits',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: Color(0xFF14151D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Benefits List
                    ...plans.map((plan) => _Benefit(plan: plan)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PlanTabs extends StatelessWidget {
  const _PlanTabs({
    required this.plans,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<SubscriptionPlanModel> plans;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(plans.length, (index) {
          final plan = plans[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedIndex == index
                      ? const Color(0xFF6F39E8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: selectedIndex == index
                      ? [
                          const BoxShadow(
                            color: Color(0xFF6F39E8),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  plan.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selectedIndex == index
                        ? Colors.white
                        : const Color(0xFF6E6F7A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.currentPlanCode,
    required this.onBought,
  });

  final SubscriptionPlanModel plan;
  final String currentPlanCode;
  final VoidCallback onBought;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan.code.toLowerCase() == 'premium';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isPremium ? const Color(0xFF6F39E8) : const Color(0xFFE5E5EA),
          width: isPremium ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPremium
                ? const Color(0xFF6F39E8).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14151D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.billingCycle.toUpperCase()} plan',
                      style: const TextStyle(
                        color: Color(0xFF747683),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6F39E8), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'BEST VALUE',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${plan.priceUsd.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: Color(0xFF14151D),
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '/mo',
                  style: TextStyle(
                    color: Color(0xFF747683),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...plan.features.map((feature) => _FeatureItem(feature)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _showUpgradeDialog(context, plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium
                    ? const Color(0xFF6F39E8)
                    : const Color(0xFFF0F0F5),
                foregroundColor: isPremium
                    ? Colors.white
                    : const Color(0xFF6F39E8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                currentPlanCode == plan.code.toLowerCase()
                    ? 'Current Plan'
                    : (plan.isFree ? 'Free Plan' : 'Buy / Upgrade'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isPremium ? Colors.white : const Color(0xFF6F39E8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, SubscriptionPlanModel plan) {
    if (plan.isFree || currentPlanCode == plan.code.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already on this plan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Upgrade to ${plan.name}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to upgrade to the ${plan.name} plan? You will be charged \$${plan.priceUsd.toStringAsFixed(0)}/month.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8B8D98),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final service = SubscriptionService.instance;
              final result = await service.buyOrUpgrade(
                planId: plan.id,
                isUpgrade: currentPlanCode != 'free',
                paymentMethod: 'card',
                autoRenew: true,
              );
              if (!context.mounted) return;
              if (result == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not start checkout. Try again.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                return;
              }

              final ok = await service.confirmPayment(result.paymentIntentId);
              if (!context.mounted) return;
              if (ok) {
                onBought();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subscription activated: ${plan.name}'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF0E9186),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment failed. Please retry checkout.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6F39E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Confirm Upgrade'),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBFF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.check, size: 12, color: Color(0xFF6F39E8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF3A3B46),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.plan});

  final SubscriptionPlanModel plan;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan.code.toLowerCase() == 'premium';
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFF8F6FF) : const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium
              ? const Color(0xFF6F39E8).withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                plan.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isPremium
                      ? const Color(0xFF14151D)
                      : const Color(0xFF8F919C),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${plan.priceUsd.toStringAsFixed(0)}/mo',
                style: TextStyle(
                  fontSize: 12,
                  color: isPremium
                      ? const Color(0xFF6F39E8)
                      : const Color(0xFFB0B2BE),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...plan.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: isPremium
                        ? const Color(0xFF6F39E8)
                        : const Color(0xFF8F919C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 14,
                        color: isPremium
                            ? const Color(0xFF14151D)
                            : const Color(0xFF8F919C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
