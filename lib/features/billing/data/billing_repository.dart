import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
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
}
