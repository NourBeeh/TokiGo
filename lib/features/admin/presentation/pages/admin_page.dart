import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/l10n/app_localizations.dart';
import 'admin_content_tab.dart';
import 'admin_providers_tab.dart';

/// Admin panel hub (ADM-A2): Home content management + API provider
/// switching. Root route outside the shell (same pattern as `/ai-chat`).
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : null,
                      tooltip: l10n.back,
                    ),
                    Expanded(
                      child: Text(
                        l10n.adminPanel,
                        style: typography.title
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
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
          ),
        ),
      ),
    );
  }
}
