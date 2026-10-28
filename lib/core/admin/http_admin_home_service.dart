import 'package:tokigo/core/admin/admin_home_service.dart';
import 'package:tokigo/core/admin/http_admin_service_base.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// HTTP implementation of the legacy [AdminHomeService] contract over the
/// backend admin endpoints (`/admin/home/*`, workstream ADM-A1).
///
/// The admin UI itself uses [AdminHomeContentService] (raw rows with drafts,
/// scheduling and content payloads); this class exists so the stable contract
/// keeps its first real implementation without any signature change.
class HttpAdminHomeService with AdminHttpMixin implements AdminHomeService {
  HttpAdminHomeService({required this.apiClient, required this.tokenStorage});

  final ApiClient apiClient;

  @override
  final SecureTokenStorage tokenStorage;

  @override
  Future<List<HomeSection>> listSections() async {
    final result = await apiClient.get<List<dynamic>>(
      '/admin/home/sections',
      headers: await authHeaders(),
    );
    if (result.valueOrNull == null) throwOnFailure(result);
    final rows = (result.valueOrNull ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    return rows.map(_sectionFromAdminRow).toList(growable: false);
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
  Future<void> setVisibility(String cardId, bool visible) async {
    await updateCard(
      cardId: cardId,
      patch: <String, dynamic>{'isVisible': visible},
    );
  }

  @override
  Future<void> setExpiration(String cardId, DateTime? expiresAt) async {
    await updateCard(
      cardId: cardId,
      patch: <String, dynamic>{
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
      },
    );
  }

  @override
  Future<void> updateOfferPrice({
    required String offerId,
    required double price,
  }) async {
    await updateCard(
      cardId: offerId,
      patch: <String, dynamic>{
        'content': <String, dynamic>{'price': price},
      },
    );
  }
}

/// Parses one raw admin section row into the presentation [HomeSection] so
/// the legacy contract (and any live preview) can consume it unchanged.
HomeSection _sectionFromAdminRow(Map<String, dynamic> row) {
  final items = <HomeItem>[];
  for (final rawCard in (row['cards'] as List? ?? const <dynamic>[])) {
    if (rawCard is! Map) continue;
    final card = Map<String, dynamic>.from(rawCard);
    final content = card['content'] is Map
        ? Map<String, dynamic>.from(
            (card['content'] as Map).map((k, v) => MapEntry(k.toString(), v)),
          )
        : <String, dynamic>{};
    items.add(
      HomeItem(
        id: card['id']?.toString() ?? '',
        type: _parseCardType(card['cardType']?.toString()),
        title: content['title']?.toString() ?? '',
        subtitle: content['subtitle']?.toString(),
        description: content['description']?.toString(),
        imageUrl: content['imageUrl']?.toString(),
        price: (content['price'] as num?)?.toDouble(),
        currency: content['currency']?.toString(),
        rating: (content['rating'] as num?)?.toDouble(),
        reviewCount: (content['reviewCount'] as num?)?.toInt(),
        badge: content['badge']?.toString(),
        highlights:
            (content['highlights'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        tags:
            (content['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        actionLabel: (content['actionLabel'] ?? content['action'])?.toString(),
        rawPrice: (content['rawPrice'] as num?)?.toDouble(),
        metadata: content['metadata'] is Map
            ? Map<String, dynamic>.from(
                (content['metadata'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v),
                ),
              )
            : const {},
      ),
    );
  }
  return HomeSection(
    id: row['id']?.toString() ?? '',
    title: row['title']?.toString() ?? '',
    subtitle: row['subtitle']?.toString(),
    layout: _parseLayout(row['layout']?.toString()),
    items: items,
  );
}

HomeCardType _parseCardType(String? value) {
  switch (value?.toLowerCase()) {
    case 'flight':
      return HomeCardType.flight;
    case 'hotel':
      return HomeCardType.hotel;
    case 'car':
      return HomeCardType.car;
    case 'package':
      return HomeCardType.package;
    case 'destination':
      return HomeCardType.destination;
    default:
      return HomeCardType.deal;
  }
}

HomeSectionLayout _parseLayout(String? value) {
  switch (value?.toLowerCase()) {
    case 'horizontal':
      return HomeSectionLayout.horizontal;
    case 'horizontalpeek':
      return HomeSectionLayout.horizontalPeek;
    case 'grid':
      return HomeSectionLayout.grid;
    default:
      return HomeSectionLayout.vertical;
  }
}
