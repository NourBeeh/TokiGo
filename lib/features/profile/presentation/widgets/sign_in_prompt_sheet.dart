import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_failure_message.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/auth/auth_state.dart';
import 'package:tokigo/core/auth/google_auth_config.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/features/profile/application/wishlist_controller.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Saves (or removes) [offer], asking a guest to sign in first when they are
/// adding to the wishlist.
///
/// The heart is a guest's door into the account: everything else stays open,
/// but keeping a stay needs an account, so the tap becomes an invitation
/// instead of a silent no-op. Removing never prompts — a guest must always be
/// able to undo their own local save.
Future<void> setSavedWithAuth(
  BuildContext context,
  WidgetRef ref,
  HotelOffer offer,
  bool saved,
) async {
  if (saved && ref.read(authUserProvider) == null) {
    final bool signedIn = await showSignInPrompt(context);
    if (!signedIn) return;
  }
  ref.read(wishlistProvider.notifier).setSaved(offer, saved);
}

/// The soft invitation to sign in. Returns true when the traveller ends up
/// signed in (so the caller can finish the action they started).
Future<bool> showSignInPrompt(BuildContext context) async {
  final bool? signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokigoColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadiusDirectional.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
    ),
    builder: (BuildContext sheetContext) => const _SignInPromptSheet(),
  );
  return signedIn ?? false;
}

class _SignInPromptSheet extends ConsumerStatefulWidget {
  const _SignInPromptSheet();

  @override
  ConsumerState<_SignInPromptSheet> createState() => _SignInPromptSheetState();
}

class _SignInPromptSheetState extends ConsumerState<_SignInPromptSheet> {
  /// The method shown as the primary action. Only Google is wired, so it *is*
  /// the available method; the full sign-in page stays a quiet fallback.
  Future<void> _signInWithGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (ref.read(authUserProvider) != null) {
      Navigator.of(context).pop(true);
    }
  }

  void _openAuthPage() {
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop(false);
    router.push('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tc = context.tokigoColors;
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    final AuthState auth = ref.watch(authControllerProvider);
    final bool loading = auth is AuthLoading;
    final bool googleReady = GoogleAuthConfig.isConfigured;

    final String? errorMessage = switch (auth) {
      AuthError(:final error) => authFailureMessage(error, action: AuthAction.google),
      _ => null,
    };

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tc.hairlineStrong,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tc.dangerContainer,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 30,
                    color: tc.danger,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.signInSheetTitle,
                textAlign: TextAlign.center,
                style: typography.title.copyWith(color: tc.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.signInSheetBody,
                textAlign: TextAlign.center,
                style: typography.body.copyWith(color: tc.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Benefit(
                icon: Icons.trending_down_rounded,
                text: l10n.signInSheetBenefitPrice,
              ),
              _Benefit(
                icon: Icons.card_travel_rounded,
                text: l10n.signInSheetBenefitTrips,
              ),
              _Benefit(
                icon: Icons.auto_awesome_rounded,
                text: l10n.signInSheetBenefitFeatures,
              ),
              _Benefit(
                icon: Icons.devices_rounded,
                text: l10n.signInSheetBenefitSync,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (errorMessage != null) ...<Widget>[
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: typography.body.copyWith(color: tc.danger),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (googleReady)
                AppButton(
                  label: l10n.continueWithGoogle,
                  leadingIcon: Icons.g_mobiledata,
                  onPressed: loading ? null : _signInWithGoogle,
                )
              else
                AppButton(
                  label: l10n.signIn,
                  onPressed: loading ? null : _openAuthPage,
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.signInSheetNotNow,
                type: AppButtonType.ghost,
                size: AppButtonSize.sm,
                onPressed: loading
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "why sign in" row: a soft tinted disc with a glyph, then the benefit.
class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tc.surfaceTertiary,
            ),
            child: Icon(icon, size: 19, color: tc.textPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: typography.body.copyWith(color: tc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
