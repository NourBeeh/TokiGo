import 'package:flutter/material.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/features/search/application/providers/search_view_providers.dart';
import 'package:tokigo/features/search/domain/search_view_mode.dart';

/// One compact button that switches between list and map.
///
/// **Why not the segmented control it used to be?** It sits at the end of a
/// pushed page's header row, beside the back control, the page title and the
/// travel-mood action. Two labelled segments needed ~160dp, which left the
/// title only 88dp on a 360dp phone — "Hotels" rendered as "H…". A single
/// 48dp target keeps the whole feature, one tap away, and gives the title its
/// room back. The current mode is still visible (the button fills with the
/// brand colour in map mode) and still announced to screen readers.
class SearchViewToggle extends ConsumerWidget {
  const SearchViewToggle({super.key, this.tooltip});

  /// Optional override for the action tooltip.
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(searchViewModeProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMap = mode == SearchViewMode.map;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: IconButton(
        tooltip: tooltip ?? (isMap ? l10n.viewList : l10n.viewMap),
        onPressed: () => ref.read(searchViewModeProvider.notifier).state = isMap
            ? SearchViewMode.list
            : SearchViewMode.map,
        style: IconButton.styleFrom(
          backgroundColor: isMap ? cs.primary : cs.surfaceContainerHighest,
          foregroundColor: isMap ? cs.onPrimary : cs.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        icon: Icon(isMap ? Icons.map_outlined : Icons.view_list_rounded),
      ),
    );
  }
}
