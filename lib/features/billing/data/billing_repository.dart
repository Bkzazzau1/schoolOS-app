import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../domain/billing_invoice.dart';
import '../domain/subscription_summary.dart';

class BillingRepository {
  BillingRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<OrganizationSubscriptionSummary> organizationSubscription(
    String organizationId,
  ) async {
    final data = await _api.get(
      'organizations/$organizationId/subscription/',
    );
    if (data is! Map) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    return OrganizationSubscriptionSummary.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<List<BillingPlan>> plans() async {
    final data = await _api.get('plans/');
    if (data is! Map || data['plans'] is! List) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    return [
      for (final item in data['plans'] as List)
        if (item is Map)
          BillingPlan.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<List<BillingInvoice>> invoices(String organizationId) async {
    final data = await _api.get(
      'organizations/$organizationId/billing/invoices/',
    );
    if (data is! Map || data['invoices'] is! List) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    return [
      for (final item in data['invoices'] as List)
        if (item is Map)
          BillingInvoice.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<BillingInvoice> issueInvoice(String organizationId) async {
    final data = await _api.post(
      'organizations/$organizationId/billing/invoices/',
      body: const {},
    );
    if (data is! Map) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    return BillingInvoice.fromJson(Map<String, dynamic>.from(data));
  }

  Future<BillingCheckout> initializeCheckout({
    required String organizationId,
    required String invoiceId,
  }) async {
    final data = await _api.post(
      'organizations/$organizationId/billing/invoices/$invoiceId/checkout/',
      body: const {},
    );
    if (data is! Map) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    try {
      return BillingCheckout.fromJson(Map<String, dynamic>.from(data));
    } on FormatException {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
  }

  Future<BillingCheckout> verifyPayment({
    required String organizationId,
    required String reference,
  }) async {
    final data = await _api.post(
      'organizations/$organizationId/billing/payments/$reference/verify/',
      body: const {},
    );
    if (data is! Map) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
    try {
      return BillingCheckout.fromJson(Map<String, dynamic>.from(data));
    } on FormatException {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }
  }
}
