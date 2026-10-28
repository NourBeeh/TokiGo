import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_breakpoints.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/features/admin/presentation/pages/admin_content_tab.dart';
import 'package:tokigo/features/admin/presentation/pages/admin_providers_tab.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Admin panel hub (ADM-A2): Home content management + API provider
/// switching. Root route outside the shell (same pattern as `/ai-chat`).
///
/// Admin is a UTILITARIAN surface (doc 23 §10): it uses the tokens but not the
/// editorial scale.
///
/// * the title is `title` 25/700 — **not** the 36/800 display;
/// * the back control sits inline beside the title, as on every pushed page;
/// * the tables run at 48pt rows with `body` 15/400 cells and `label` 11/600
///   headers, and the section gaps are `lg` 16 — the 8pt editorial rhythm is
///   deliberately compressed here;
/// * the status pills use the Bag palette.
///
/// **OWNER DECISION D9 (2026-10-20): tablet/desktop only.** The tables need at
/// least 480pt of width; below that the console says so honestly instead of
/// pretending a table fits.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  /// The narrowest width the admin tables are designed for.
  static const double minimumWidth = AppBreakpoints.compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    final bool tooSmall = MediaQuery.sizeOf(context).width < minimumWidth;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: AiEntranceAnimation(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AdminHeader(title: l10n.adminPanel),
                if (tooSmall)
                  const Expanded(child: _AdminTooSmall())
                else ...<Widget>[
                  TabBar(
                    labelStyle: typography.captionSemibold,
                    unselectedLabelStyle: typography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    tabs: <Tab>[
                      Tab(text: l10n.adminContent),
                      Tab(text: l10n.adminProviders),
                    ],
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.brand,
                    dividerColor: AppColors.outline,
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        AdminContentTab(),
                        AdminProvidersTab(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The admin header — the same rhythm as [AppPageHeader] (the back control
/// inline beside the title), with the admin's own title scale.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          const AppBackButton(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.title.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The narrow-screen notice: the console needs a real width, and says so.
class _AdminTooSmall extends StatelessWidget {
  const _AdminTooSmall();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        child: AppMessageState(
          icon: Icons.desktop_windows_outlined,
          hue: AppColors.textTertiary,
          title: l10n.adminTabletOnlyTitle,
          body: l10n.adminTabletOnlyBody,
        ),
      ),
    );
  }
}
