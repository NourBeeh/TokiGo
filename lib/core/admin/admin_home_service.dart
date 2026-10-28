import '../domain/models/home/home_section.dart';

abstract interface class AdminHomeService {
  Future<List<HomeSection>> listSections();
  Future<void> updateSection({
    required String sectionId,
    required Map<String, dynamic> patch,
  });
  Future<void> reorderSections(List<String> sectionIds);
  Future<void> createCard({required Map<String, dynamic> card});
  Future<void> updateCard({
    required String cardId,
    required Map<String, dynamic> patch,
  });
  Future<void> deleteCard(String cardId);
  Future<void> setVisibility(String cardId, bool visible);
  Future<void> setExpiration(String cardId, DateTime? expiresAt);
  Future<void> updateOfferPrice({
    required String offerId,
    required double price,
  });
}
