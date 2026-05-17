import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class SubscriptionPlanModel {
  final int id;
  final String name;
  final String code;
  final double priceUsd;
  final String billingCycle;
  final List<String> features;
  final bool isActive;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.code,
    required this.priceUsd,
    required this.billingCycle,
    required this.features,
    required this.isActive,
  });

  bool get isFree => code.toLowerCase() == 'free' || priceUsd <= 0;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      priceUsd: double.tryParse((json['price_usd'] ?? '0').toString()) ?? 0,
      billingCycle: (json['billing_cycle'] ?? 'monthly').toString(),
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

class CurrentSubscriptionModel {
  final String effectivePlanCode;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool autoRenew;
  final SubscriptionPlanModel plan;

  const CurrentSubscriptionModel({
    required this.effectivePlanCode,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.autoRenew,
    required this.plan,
  });

  factory CurrentSubscriptionModel.fromJson(Map<String, dynamic> json) {
    final planJson = (json['plan'] as Map<String, dynamic>? ?? const {});
    final subscription = (json['subscription'] as Map<String, dynamic>? ?? const {});
    return CurrentSubscriptionModel(
      effectivePlanCode: (json['effective_plan_code'] ?? 'free').toString(),
      status: (json['status'] ?? subscription['status'] ?? 'inactive').toString(),
      startDate: DateTime.tryParse((subscription['start_date'] ?? '').toString()),
      endDate: DateTime.tryParse((subscription['end_date'] ?? '').toString()),
      autoRenew: (subscription['auto_renew'] as bool?) ?? false,
      plan: SubscriptionPlanModel.fromJson(planJson),
    );
  }
}

class SubscribeResult {
  final String message;
  final String paymentIntentId;
  final String clientSecret;
  final Map<String, dynamic> orderSummary;

  const SubscribeResult({
    required this.message,
    required this.paymentIntentId,
    required this.clientSecret,
    required this.orderSummary,
  });

  factory SubscribeResult.fromJson(Map<String, dynamic> json) {
    return SubscribeResult(
      message: (json['message'] ?? '').toString(),
      paymentIntentId: (json['payment_intent_id'] ?? '').toString(),
      clientSecret: (json['client_secret'] ?? '').toString(),
      orderSummary: (json['order_summary'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  Future<Map<String, String>?> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken') ?? '';
    if (token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<List<SubscriptionPlanModel>> getPlans() async {
    final headers = await _authHeaders();
    if (headers == null) return const [];
    final res = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/plans/'), headers: headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return const [];
    return (decoded['plans'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlanModel.fromJson)
        .toList();
  }

  Future<CurrentSubscriptionModel?> getCurrentSubscription() async {
    final headers = await _authHeaders();
    if (headers == null) return null;
    final res = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/current-subscription/'), headers: headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return CurrentSubscriptionModel.fromJson(decoded);
  }

  Future<SubscribeResult?> buyOrUpgrade({
    required int planId,
    required bool isUpgrade,
    String paymentGateway = 'stripe',
    String paymentMethod = 'card',
    String couponCode = '',
    bool autoRenew = true,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) return null;
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/create-payment/'),
          headers: headers,
          body: jsonEncode({
            'plan_id': planId,
            'flow': isUpgrade ? 'upgrade' : 'subscribe',
            'payment_gateway': paymentGateway,
            'payment_method': paymentMethod,
            'coupon_code': couponCode,
            'auto_renew': autoRenew,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return SubscribeResult.fromJson(decoded);
  }

  Future<bool> confirmPayment(String paymentIntentId) async {
    final headers = await _authHeaders();
    if (headers == null) return false;
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/confirm-payment/'),
          headers: headers,
          body: jsonEncode({'payment_intent_id': paymentIntentId}),
        )
        .timeout(const Duration(seconds: 20));
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}
