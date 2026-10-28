import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// The heart over the detail photo — the wishlist's only source (the owner,
/// 2026-10-20). Only a stay can be saved, so only a stay gets the heart.
class OfferDetailsStayHeart extends StatelessWidget {
  const OfferDetailsStayHeart({
    super.key,
    required this.saved,
    required this.onChanged,
  });

  final bool saved;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: AppSpacing.xs,
          end: AppSpacing.lg,
        ),
        child: CardFavorite(
          value: saved,
          onChanged: onChanged,
          size: 40,
          onImage: true,
        ),
      ),
    );
  }
}
