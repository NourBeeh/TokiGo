import 'package:tokigo/core/admin/http_admin_service_base.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// Raw admin-shaped section view: drafts, scheduling and full content payload
/// preserved (unlike the flattened public feed).
class AdminHomeCardView {
  const AdminHomeCardView({
    required this.id,
    required this.cardType,
    required this.content,
    required this.isVisible,
    required this.status,
    this.order = 0,
    this.publishAt,
    this.expiresAt,
  });

  final String id;
  final String cardType;
  final Map<String, dynamic> content;
  final bool isVisible;
  final String status;
  final int order;
  final DateTime? publishAt;
  final DateTime? expiresAt;

  factory AdminHomeCardView.fromJson(Map<String, dynamic> json) {
    return AdminHomeCardView(
      id: json['id']?.toString() ?? '',
      cardType: json['cardType']?.toString() ?? 'deal',
      content: json['content'] is Map
          ? Map<String, dynamic>.from(
              (json['content'] as Map).map((k, v) => MapEntry(k.toString(), v)),
            )
          : <String, dynamic>{},
      isVisible: json['isVisible'] != false,
      status: json['status']?.toString() ?? 'published',
      order: (json['order'] as num?)?.toInt() ?? 0,
      publishAt: _date(json['publishAt']),
      expiresAt: _date(json['expiresAt']),
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

/// Raw admin-shaped section row with its cards.
class AdminHomeSectionView {
  const AdminHomeSectionView({
    required this.id,
    required this.title,
    required this.layout,
    required this.isVisible,
    required this.status,
    required this.cards,
    this.subtitle,
    this.order = 0,
    this.publishAt,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String layout;
  final bool isVisible;
  final String status;
  final int order;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final List<AdminHomeCardView> cards;

  factory AdminHomeSectionView.fromJson(Map<String, dynamic> json) {
    return AdminHomeSectionView(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      layout: json['layout']?.toString() ?? 'vertical',
      isVisible: json['isVisible'] != false,
      status: json['status']?.toString() ?? 'published',
      order: (json['order'] as num?)?.toInt() ?? 0,
      publishAt: AdminHomeCardView._date(json['publishAt']),
      expiresAt: AdminHomeCardView._date(json['expiresAt']),
      cards: (json['cards'] as List? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (raw) => AdminHomeCardView.fromJson(Map<String, dynamic>.from(raw)),
          )
          .toList(growable: false),
    );
  }
}

/// Full admin content management contract (ADM-A1 backend).
abstract interface class AdminHomeContentService {
  Future<List<AdminHomeSectionView>> listSections();
  Future<void> createSection({required Map<String, dynamic> section});
  Future<void> updateSection({
    required String sectionId,
    required Map<String, dynamic> patch,
  });
  Future<void> deleteSection(String sectionId);
  Future<void> reorderSections(List<String> sectionIds);
  Future<void> createCard({required Map<String, dynamic> card});
  Future<void> updateCard({
    required String cardId,
    required Map<String, dynamic> patch,
  });
  Future<void> deleteCard(String cardId);
  Future<void> reorderCards(List<String> cardIds);
}

/// HTTP implementation over `/admin/home/*`.
class HttpAdminContentService
    with AdminHttpMixin
    implements AdminHomeContentService {
  HttpAdminContentService({
    required this.apiClient,
    required this.tokenStorage,
  });

  final ApiClient apiClient;

  @override
  final SecureTokenStorage tokenStorage;

  @override
  Future<List<AdminHomeSectionView>> listSections() async {
    final result = await apiClient.get<List<dynamic>>(
      '/admin/home/sections',
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
    return (result.valueOrNull ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (raw) =>
              AdminHomeSectionView.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> createSection({required Map<String, dynamic> section}) async {
    final result = await apiClient.post<Map<String, dynamic>>(
      '/admin/home/sections',
      body: section,
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }

  @override
  Future<void> updateSection({
    required String sectionId,
    required Map<String, dynamic> patch,
  }) async {
    final result = await apiClient.patch<Map<String, dynamic>>(
      '/admin/home/sections/$sectionId',
      body: patch,
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }

  @override
  Future<void> deleteSection(String sectionId) async {
    final result = await apiClient.delete<Map<String, dynamic>>(
      '/admin/home/sections/$sectionId',
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }

  @override
  Future<void> reorderSections(List<String> sectionIds) async {
    final result = await apiClient.post<Map<String, dynamic>>(
      '/admin/home/sections/reorder',
      body: <String, dynamic>{'ids': sectionIds},
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }

  @override
  Future<void> createCard({required Map<String, dynamic> card}) async {
    final result = await apiClient.post<Map<String, dynamic>>(
      '/admin/home/cards',
      body: card,
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }

  @override
  Future<void> updateCard({
    required String cardId,
    required Map<String, dynamic> patch,
  }) async {
    final result = await apiClient.patch<Map<String, dynamic>>(
      '/admin/home/cards/$cardId',
      body: patch,
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }

  @override
  Future<void> deleteCard(String cardId) async {
    final result = await apiClient.delete<Map<String, dynamic>>(
      '/admin/home/cards/$cardId',
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }

  @override
  Future<void> reorderCards(List<String> cardIds) async {
    final result = await apiClient.post<Map<String, dynamic>>(
      '/admin/home/cards/reorder',
      body: <String, dynamic>{'ids': cardIds},
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
  }
}
