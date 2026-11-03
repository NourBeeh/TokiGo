import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/auth/google_auth_config.dart';
import 'package:tokigo/core/auth/auth_state.dart';
import 'package:tokigo/core/auth/user_model.dart';
import 'package:tokigo/core/network/user_facing_message.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';

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
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        // `bottom: false` left the menu's last row (sign out) under the
        // Android navigation bar (the pill it was written for is gone).
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppPageHeader(
                title: l10n.profile,
                trailing: Pressable.wrap(
                  child: IconButton(
                    tooltip: l10n.settings,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                ),
              ),
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
                      hue: context.tokigoColors.danger,
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
                          hue: context.tokigoColors.brand,
                          title: l10n.profileGuestTitle,
                          body: l10n.profileGuestBody,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (GoogleAuthConfig.isConfigured)
                          Pressable.wrap(
                            child: OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle(),
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: Text(l10n.continueWithGoogle),
                            ),
                          ),
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
              Stack(
                alignment: Alignment.center,
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
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: Pressable(
                      onTap: () => context.push('/edit-profile'),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: context.tokigoColors.brand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: typography.titleMedium.copyWith(
                      color: context.tokigoColors.textPrimary,
                    ),
                  ),
                  Pressable.wrap(
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      onPressed: () => context.push('/edit-profile'),
                    ),
                  ),
                ],
              ),
              if (email.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: typography.body.copyWith(
                    color: context.tokigoColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Edit profile — at top of the page.
        // (removed: edit action now lives as pencil icon next to the name)
        Container(
          decoration: BoxDecoration(
            color: context.tokigoColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.tokigoColors.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: _MenuRow(
            icon: Icons.luggage_outlined,
            label: l10n.bag,
            onTap: () => context.push('/bag'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: context.tokigoColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.tokigoColors.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              if (user.isAdmin) ...<Widget>[
                _MenuRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: l10n.adminPanel,
                  onTap: () => context.push('/admin'),
                ),
                const _MenuDivider(),
              ],
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
      color: context.tokigoColors.brandContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: typography.title.copyWith(
          color: context.tokigoColors.onBrandContainer,
        ),
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
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
      color: context.tokigoColors.divider,
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
    return Pressable(
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
              Icon(icon, size: 20, color: context.tokigoColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    color: context.tokigoColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(chevron, size: 20, color: context.tokigoColors.textTertiary),
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
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Pressable(
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
                color: context.tokigoColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
