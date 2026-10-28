import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/features/search/presentation/widgets/search_states_view.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Tour packages — the surface exists, the provider does not.
///
/// **OWNER DECISION (2026-10-18): the app never displays a fabricated price,
/// rating or image.** This page used to list six invented packages (invented
/// prices $289–$749, invented ratings 4.5–4.8 with review counts, invented
/// inclusions), all sharing one placeholder picture, behind a search form that
/// merely filtered that invented list during a fake 600ms "search". The list is
/// gone, and so is the form: a search form that cannot search is itself a fake
/// capability. What remains is the truthful state plus the two verticals that
/// ARE live today, so the page is still useful instead of a dead end.
///
/// The route, the scaffold identity and [PackageSearchCard] are kept intact —
/// a real package provider plugs straight back in here.
class PackagesSearchPage extends StatelessWidget {
  const PackagesSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SearchScaffold(
      title: l10n.searchPackages,
      subtitle: l10n.packagesSubtitle,
      form: const SizedBox.shrink(),
      body: Column(
        children: <Widget>[
          SearchStatesView.idle(
            icon: Icons.tour_outlined,
            title: l10n.packagesUnavailableTitle,
            body: l10n.packagesUnavailableBody,
          ),
          // Two real destinations instead of a dead end. Inset + a clear gap:
          // two full-bleed tinted bars stacked edge-to-edge read as one blob.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              children: <Widget>[
                AppButton(
                  label: l10n.findFlights,
                  type: AppButtonType.secondary,
                  onPressed: () => context.push('/flights'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: l10n.findHotels,
                  type: AppButtonType.secondary,
                  onPressed: () => context.push('/hotels'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
