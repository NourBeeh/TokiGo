/// Admin-facing view of one backend API provider.
///
/// Mirrors the persisted `providers` table (ADM-B1): which vertical it serves,
/// whether it is active, its ordering priority and last health-probe result.
class ManagedProvider {
  const ManagedProvider({
    required this.providerKey,
    required this.name,
    required this.vertical,
    required this.isActive,
    required this.priority,
    required this.isFallback,
    required this.healthStatus,
    this.latencyMs,
    this.lastCheckedAt,
  });

  final String providerKey;
  final String name;
  final String vertical; // flight | hotel | car
  final bool isActive;
  final int priority;
  final bool isFallback;
  final String healthStatus; // healthy | unhealthy | unknown
  final int? latencyMs;
  final DateTime? lastCheckedAt;

  factory ManagedProvider.fromJson(Map<String, dynamic> json) {
    return ManagedProvider(
      providerKey: json['providerKey']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      vertical: json['vertical']?.toString() ?? '',
      isActive: json['isActive'] == true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isFallback: json['isFallback'] == true,
      healthStatus: json['healthStatus']?.toString() ?? 'unknown',
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      lastCheckedAt: json['lastCheckedAt'] == null
          ? null
          : DateTime.tryParse(json['lastCheckedAt'].toString()),
    );
  }
}

/// Contract for admin provider management (switch/prioritise/health-check).
abstract interface class AdminProviderService {
  Future<List<ManagedProvider>> listProviders();
  Future<ManagedProvider> setStatus(String key, bool isActive);
  Future<ManagedProvider> setPriority(String key, int priority);
  Future<ManagedProvider> runHealthCheck(String key);
  Future<void> refreshRegistry();
}
