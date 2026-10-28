import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/auth/auth_state.dart';
import 'package:tokigo/core/auth/user_model.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/ui/language_sheet.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// Profile — the account surface.
///
/// **Reference screen 9**: an identity block (avatar, name, email) over a menu
/// of account destinations.
///
/// **Honesty rules (owner, 2026-10-19):**
/// - Every menu row opens a surface that really exists. The reference's
///   "Payment methods" and "Help & support" are **not** built: there is no
///   payment-method store and no support channel behind them, and a row that
///   leads nowhere is decoration.
/// - The "Premium Member" badge is **not** built: `AuthUser` carries no
///   membership tier, so the badge would be a claim about the customer.
/// - The promo banner is **not** built: it is a stock photograph and a
///   marketing promise, neither of which this app can back.
/// - The avatar shows the provider's real photo when the account has one,
///   otherwise the account's own initial.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppPageHeader(title: l10n.profile),
              Expanded(
                child: switch (authState) {
                  AuthLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  AuthAuthenticated(:final user) => _ProfileContent(
                    user: user!,
                  ),
                  AuthError(:final error) => _CenteredState(
                    child: AppMessageState(
                      icon: Icons.cloud_off_rounded,
                      hue: AppColors.danger,
                      title: l10n.profileErrorTitle,
                      body: userFacingMessage(error, subject: 'profile'),
                      actionLabel: l10n.signIn,
                      onAction: () => context.go('/auth'),
                    ),
                  ),
                  AuthUnauthenticated() => _CenteredState(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AppMessageState(
                          icon: Icons.person_outline_rounded,
                          title: l10n.profileGuestTitle,
                          body: l10n.profileGuestBody,
                          actionLabel: l10n.signIn,
                          onAction: () => context.go('/auth'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // The wishlist lives on THIS device, so a guest can
                        // reach the stays they saved — the heart is a local
                        // action, not an account one.
                        AppButton(
                          label: l10n.profileGuestSavedPlaces,
                          type: AppButtonType.ghost,
                          leadingIcon: Icons.favorite_border_rounded,
                          onPressed: () => context.push('/bag?section=likes'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.profileGuestSavedPlacesBody,
                          textAlign: TextAlign.center,
                          style: AppTypography.forLight().caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const _AppPreferencesSection(),
                      ],
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final displayName = user.displayName?.trim() ?? '';
    final email = user.email.trim();
    final avatarUrl = user.avatarUrl?.trim() ?? '';
    final name = displayName.isNotEmpty ? displayName : l10n.profileTraveller;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: <Widget>[
        // Doc 22 §2.2 — the identity block is centred: avatar ⌀80, the name
        // at 22/700, the email under it. No membership badge: the account
        // carries no tier, and a badge would be a claim about the customer.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: <Widget>[
              ClipOval(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: avatarUrl.isNotEmpty
                      ? CardImage(
                          url: avatarUrl,
                          fallbackIcon: Icons.person_rounded,
                          semanticLabel: name,
                          fit: BoxFit.cover,
                        )
                      : _InitialAvatar(name: name, email: email),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: typography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (email.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: typography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _AppPreferencesSection(),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              // Only surfaces that exist: each of these opens a real page.
              _MenuRow(
                icon: Icons.luggage_rounded,
                label: l10n.myTrips,
                onTap: () => context.push('/bag'),
              ),
              const _MenuDivider(),
              _MenuRow(
                icon: Icons.notifications_none_rounded,
                label: l10n.notifications,
                onTap: () => context.push('/notifications'),
              ),
              const _MenuDivider(),
              _MenuRow(
                icon: Icons.settings_outlined,
                label: l10n.settings,
                onTap: () => context.push('/settings'),
              ),
              if (user.isAdmin) ...<Widget>[
                const _MenuDivider(),
                _MenuRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: l10n.adminPanel,
                  onTap: () => context.push('/admin'),
                ),
              ],
              const _MenuDivider(),
              // Doc 22 §2.2 — sign out is the only `danger` element here, it
              // carries no chevron, and it is centred.
              _DangerRow(
                label: l10n.signOut,
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The account's own initial — the honest stand-in when no avatar photo was
/// provided by the identity provider.
class _AppPreferencesSection extends ConsumerWidget {
  const _AppPreferencesSection();

  static const List<String> _currencies = <String>[
    'USD',
    'EUR',
    'EGP',
    'SAR',
    'AED',
    'GBP',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final currency = ref.watch(currencyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            l10n.settingsPreferences,
            style: AppTypography.forLight().label.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              _PreferenceRow(
                icon: Icons.translate_rounded,
                label: l10n.settingsAppLanguage,
                value: locale.languageCode == 'ar' ? 'العربية' : 'English',
                onTap: () => showLanguageSheet(context),
              ),
              const _MenuDivider(),
              _PreferenceRow(
                icon: Icons.payments_outlined,
                label: l10n.currency,
                value: currency,
                onTap: () => _pickCurrency(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final String current = ref.read(currencyProvider);
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.currency,
                style: AppTypography.forLight().title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            for (final String code in _currencies)
              InkWell(
                onTap: () => Navigator.of(sheetContext).pop(code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          code,
                          style: AppTypography.forLight().body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (code == current)
                        const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: AppColors.brand,
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (chosen != null) {
      ref.read(currencyProvider.notifier).state = chosen;
    }
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.forLight().bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                value,
                style: AppTypography.forLight().caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(chevron, size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    final initial = source.isEmpty ? '?' : source[0].toUpperCase();
    return Container(
      color: AppColors.brandContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: typography.title.copyWith(color: AppColors.onBrandContainer),
      ),
    );
  }
}

/// Centres an honest state in the free space, and still allows it to scroll
/// when the text scale needs the room.
class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
      color: AppColors.divider,
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    // The chevron points forward in the reading direction.
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded;
    return InkWell(
      onTap: onTap,
      // Doc 22 §2.2 — a menu row is 56 tall: the icon column, the label and
      // the chevron, with the fill (never a ripple) carrying the press.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(chevron, size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign out — a `danger` label, centred, no chevron (doc 22 §2.2).
class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Center(
            child: Text(
              label,
              style: typography.bodyMedium.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
