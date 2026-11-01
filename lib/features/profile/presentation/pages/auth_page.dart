import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_failure_message.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/auth/google_auth_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ai_entrance_animation.dart';
import '../../../../core/widgets/page_header.dart';

/// Sign-in / registration page (Phase 17).
///
/// One form with a mode toggle. On success the router-level listener on
/// [authUserProvider] sends the user to their profile.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _submittedOnce = false;

  /// Which control was used last, so a failure is described accurately.
  AuthAction _lastAction = AuthAction.password;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _lastAction = AuthAction.google);
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      context.go('/profile');
    }
  }

  String? _validateEmail(String? value) {
    if (!_submittedOnce) return null;
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (!_submittedOnce) return null;
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (_isRegisterMode && password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    // Surface a safe error message; never raw exception text.
    final errorMessage = switch (authState) {
      AuthError(:final error) => authFailureMessage(error, action: _lastAction),
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // `bottom: false` left the form's last field under the Android
        // navigation bar (the pill it was written for is gone).
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Entered with `go('/auth')` from Profile: with no history to pop,
              // the control lands back on that surface.
              const AppPageHeader(backFallbackLocation: '/profile'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (GoogleAuthConfig.isConfigured) ...[
                              OutlinedButton.icon(
                                onPressed: isLoading ? null : _signInWithGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  maximumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Google Sign-In not configured.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (errorMessage != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                errorMessage,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
