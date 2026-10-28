import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/network/user_facing_message.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submittedOnce = true);
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(authControllerProvider.notifier);
    if (_isRegisterMode) {
      await controller.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );
    } else {
      await controller.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state is AuthAuthenticated) {
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
      AuthError(:final error) => userFacingMessage(error, subject: 'sign in'),
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
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
                            Icon(
                              _isRegisterMode
                                  ? Icons.person_add_alt_1
                                  : Icons.lock_outline,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (_isRegisterMode) ...[
                              TextFormField(
                                controller: _displayNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Display name (optional)',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.next,
                                enabled: !isLoading,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.password_outlined),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: _validatePassword,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (errorMessage != null) ...[
                              Text(
                                errorMessage,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            FilledButton(
                              onPressed: isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                maximumSize: const Size.fromHeight(48),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isRegisterMode
                                          ? 'Create account'
                                          : 'Sign in',
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => setState(
                                      () => _isRegisterMode = !_isRegisterMode,
                                    ),
                              child: Text(
                                _isRegisterMode
                                    ? 'Already have an account? Sign in'
                                    : 'New here? Create an account',
                              ),
                            ),
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
