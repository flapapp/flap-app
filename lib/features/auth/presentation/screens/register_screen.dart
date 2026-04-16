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
import '../../domain/entities/registration_profile.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

@RoutePage()
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return I18n.inline('Введіть username', 'Enter username');
    }
    if (v.contains(' ')) {
      return I18n.inline(
        'Username не може містити пробіли',
        'Username cannot contain spaces',
      );
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.isEmpty) return I18n.t('enter_email');
    final at = v.indexOf('@');
    final hasValidAt = at > 0 && at < v.length - 1;
    if (!hasValidAt) {
      return I18n.inline(
        'Введіть коректний email',
        'Enter a valid email',
      );
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
      child: AppScaffold(
        appBar: AppTopBar(
          title: I18n.t('register'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthCredentialsRejected ||
              current is AuthRegistrationCompleted,
          listener: (context, state) {
            if (state is AuthCredentialsRejected) {
              final text = state.code == 'email-already-in-use'
                  ? I18n.inline(
                      'Ця електронна адреса вже використовується. Увійдіть або оберіть іншу.',
                      'This email is already in use. Sign in or choose another one.',
                    )
                  : (state.message != null && state.message!.isNotEmpty
                      ? state.message!
                      : I18n.inline(
                          'Помилка реєстрації',
                          'Registration error',
                        ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(text)),
              );
            }
            if (state is AuthRegistrationCompleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    I18n.inline(
                      'Реєстрацію завершено. Підтвердіть email і увійдіть у свій акаунт.',
                      'Registration complete. Confirm your email and sign in to your account.',
                    ),
                  ),
                  duration: const Duration(seconds: 3),
                  backgroundColor: AppColors.accentPrimary,
                ),
              );
              context.replaceRoute(LoginRoute());
            }
          },
          builder: (context, state) {
            final loading = state is AuthLoading;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          I18n.inline(
                            'Вкажіть email, username та пароль. Решту профілю заповните на наступному кроці.',
                            'Enter email, username, and password. You will complete the rest of your profile in the next step.',
                          ),
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
                                label: I18n.inline('Email', 'Email'),
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppInput(
                                controller: _usernameController,
                                label: I18n.inline('Username', 'Username'),
                                validator: _validateUsername,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppInput(
                                controller: _passwordController,
                                label: I18n.t('password'),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return I18n.t('enter_password');
                                  }
                                  if (value.length < 6) {
                                    return I18n.inline(
                                      'Пароль має бути не менше 6 символів',
                                      'Password must be at least 6 characters',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppInput(
                                controller: _confirmPasswordController,
                                label: I18n.inline(
                                  'Підтвердьте пароль',
                                  'Confirm password',
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return I18n.inline(
                                      'Підтвердьте пароль',
                                      'Confirm your password',
                                    );
                                  }
                                  if (value != _passwordController.text) {
                                    return I18n.inline(
                                      'Паролі не збігаються',
                                      'Passwords do not match',
                                    );
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (loading)
                          const Center(child: CircularProgressIndicator())
                        else
                          AppButton(
                            label: I18n.inline('Створити акаунт', 'Create account'),
                            onPressed: () {
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                              final normalizedEmail =
                                  _emailController.text.trim().toLowerCase();
                              final normalizedUsername =
                                  _usernameController.text.trim().toLowerCase();
                              context.read<AuthBloc>().add(
                                    AuthRegisterRequested(
                                      email: normalizedEmail,
                                      password: _passwordController.text.trim(),
                                      profile: RegistrationProfile(
                                        email: normalizedEmail,
                                        username: normalizedUsername,
                                      ),
                                    ),
                                  );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
