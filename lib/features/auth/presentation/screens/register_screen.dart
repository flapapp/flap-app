import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_router.dart';
import '../../../../utils/i18n.dart';
import '../../domain/entities/registration_profile.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

@RoutePage()
class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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
        backgroundColor: const Color(0xFF1e7d32),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: BlocConsumer<AuthBloc, AuthState>(
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(text)));
              }
              if (state is AuthRegistrationCompleted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      I18n.inline(
                        'Обліковий запис створено. Увійдіть, щоб продовжити.',
                        'Account created. Sign in to continue.',
                      ),
                    ),
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xFF4caf50),
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              label: Text(
                                I18n.t('back'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            I18n.t('register'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            I18n.inline(
                              'Приєднуйтесь до футбольної спільноти',
                              'Join the football community',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          _field(
                            controller: _nameController,
                            label: I18n.inline('Ім\'я', 'Name'),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? I18n.inline(
                                    'Введіть ваше ім\'я',
                                    'Enter your name',
                                  )
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _field(
                            controller: _surnameController,
                            label: I18n.inline('Прізвище', 'Surname'),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? I18n.inline(
                                    'Введіть ваше прізвище',
                                    'Enter your surname',
                                  )
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _field(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? I18n.t('enter_email')
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _field(
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
                          const SizedBox(height: 20),
                          _field(
                            controller: _confirmPasswordController,
                            label: I18n.inline(
                              'Підтвердження пароля',
                              'Confirm password',
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return I18n.inline(
                                  'Підтвердіть пароль',
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
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              onPressed: loading
                                  ? null
                                  : () {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      context.read<AuthBloc>().add(
                                        AuthRegisterRequested(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text
                                              .trim(),
                                          profile: RegistrationProfile(
                                            name: _nameController.text.trim(),
                                            surname: _surnameController.text
                                                .trim(),
                                            email: _emailController.text.trim(),
                                          ),
                                        ),
                                      );
                                    },
                              child: loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      I18n.inline('Зареєструватися', 'Sign up'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
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
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
        ),
        validator: validator,
      ),
    );
  }
}
