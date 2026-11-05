import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_discovery_card.dart';
import 'package:tokigo/features/home/presentation/widgets/discovery_product_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_card_loading.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';

/// Type dispatcher for Home feed items.
///
/// Every item — real or skeleton — renders through the SAME approved card
/// widget. A skeleton entry passes `loading: true` to that card, so the
/// placeholder is the card's own loading state and can never drift from the
/// loaded design. There is no separate legacy skeleton card any more.
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.item, this.onTap});

  final HomeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool skeleton = isHomeSkeletonItem(item);
    switch (item.type) {
      case HomeCardType.hotel:
        return HomeStayCard(
          item: item,
          margin: EdgeInsets.zero,
          onTap: onTap,
          loading: skeleton,
        );
      case HomeCardType.car:
      case HomeCardType.package:
        return DiscoveryProductCard(
          item: item,
          onTap: onTap,
          loading: skeleton,
        );
      case HomeCardType.destination:
        return DestinationDiscoveryCard(
          item: item,
          onTap: onTap,
          loading: skeleton,
        );
      case HomeCardType.deal:
        return DealCard(item: item, onTap: onTap, loading: skeleton);
      case HomeCardType.flight:
        return FlightRecommendationCard(
          item: item,
          onTap: onTap,
          loading: skeleton,
        );
    }
  }
}
