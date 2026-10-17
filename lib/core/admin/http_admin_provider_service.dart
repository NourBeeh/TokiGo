import 'package:tokigo/core/admin/admin_provider_models.dart';
import 'package:tokigo/core/admin/http_admin_service_base.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// HTTP implementation of [AdminProviderService] over `/admin/providers/*`
/// (ADM-B1): runtime switching, prioritisation and health checks.
class HttpAdminProviderService
    with AdminHttpMixin
    implements AdminProviderService {
  HttpAdminProviderService({
    required this.apiClient,
    required this.tokenStorage,
  });

  final ApiClient apiClient;

  @override
  final SecureTokenStorage tokenStorage;

  @override
  Future<List<ManagedProvider>> listProviders() async {
    final result = await apiClient.get<List<dynamic>>(
      '/admin/providers',
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
    return (result.valueOrNull ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => ManagedProvider.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  @override
  Future<ManagedProvider> setStatus(String key, bool isActive) async {
    final result = await apiClient.patch<Map<String, dynamic>>(
      '/admin/providers/$key/status',
      body: <String, dynamic>{'isActive': isActive},
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
    return ManagedProvider.fromJson(
        result.valueOrNull ?? <String, dynamic>{});
  }

  @override
  Future<ManagedProvider> setPriority(String key, int priority) async {
    final result = await apiClient.patch<Map<String, dynamic>>(
      '/admin/providers/$key/priority',
      body: <String, dynamic>{'priority': priority},
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
    return ManagedProvider.fromJson(
        result.valueOrNull ?? <String, dynamic>{});
  }

  @override
  Future<ManagedProvider> runHealthCheck(String key) async {
    final result = await apiClient.post<Map<String, dynamic>>(
      '/admin/providers/$key/health-check',
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
    return ManagedProvider.fromJson(
        result.valueOrNull ?? <String, dynamic>{});
  }

  @override
  Future<void> refreshRegistry() async {
    final result = await apiClient.post<Map<String, dynamic>>(
      '/admin/providers/refresh-registry',
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }
}
