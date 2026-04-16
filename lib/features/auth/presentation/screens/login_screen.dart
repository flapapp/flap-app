import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/ui/app_button.dart';
import '../../../../shared/ui/app_card.dart';
import '../../../../shared/ui/app_input.dart';
import '../../../../shared/ui/app_scaffold.dart';
import '../../../../shared/ui/app_top_bar.dart';
import '../../../../utils/i18n.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

@RoutePage()
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  String _messageForRejected(AuthCredentialsRejected state) {
    final code = state.code;
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return I18n.t('invalid_email_or_password');
      case 'too-many-requests':
        return I18n.t('too_many_requests');
      case 'email-not-confirmed':
        return I18n.inline(
          'Підтвердіть електронну пошту перед входом.',
          'Please confirm your email before signing in.',
        );
      default:
        return state.message ?? I18n.t('login_error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final focused = FocusScope.of(context);
        if (!focused.hasPrimaryFocus) {
          focused.unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: BlocListener<AuthBloc, AuthState>(
          listenWhen: (prev, curr) =>
              curr is AuthLoading ||
              curr is AuthAuthenticated ||
              curr is AuthCredentialsRejected,
          listener: (context, state) {
            if (state is AuthLoading) {
              setState(() => _isLoading = true);
            }
            if (state is AuthCredentialsRejected) {
              setState(() => _isLoading = false);
              final message = _messageForRejected(state);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(I18n.inline('Помилка: $message', 'Error: $message')),
                ),
              );
            }
            if (state is AuthAuthenticated) {
              setState(() => _isLoading = false);
              if (context.mounted) {
                context.replaceRoute(const MainShellRoute());
              }
            }
          },
          child: AppScaffold(
            appBar: AppTopBar(
              title: I18n.t('login'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.xl),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset('assets/logo/flap_logo.jpg', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          I18n.t('login_subtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppCard(
                          child: Column(
                            children: [
                              AppInput(
                                controller: _emailController,
                                label: I18n.t('email_or_phone'),
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return I18n.t('enter_email');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppInput(
                                controller: _passwordController,
                                label: I18n.t('password'),
                                obscureText: true,
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return I18n.t('enter_password');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(I18n.t('password_recovery_later'))),
                                    );
                                  },
                                  child: Text(I18n.t('forgot_password')),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          AppButton(
                            label: I18n.t('login'),
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                context.read<AuthBloc>().add(
                                      AuthSignInRequested(
                                        email: _emailController.text.trim(),
                                        password: _passwordController.text.trim(),
                                      ),
                                    );
                              }
                            },
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: I18n.t('no_account_register'),
                          variant: AppButtonVariant.tertiary,
                          onPressed: () => context.pushRoute(RegisterRoute()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
