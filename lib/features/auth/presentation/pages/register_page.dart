import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../router/post_auth_navigation.dart';
import '../../domain/entities/register_request.dart';
import '../bloc/auth_bloc.dart';

String _registrationErrorMessage(Failure failure) {
  return failure.when(
    cache: () => tr('il_789c156110'),
    network: (m) => m ?? tr('il_789c156110'),
    unexpected: (m) => m ?? tr('il_789c156110'),
    auth: (code, message) => message ?? tr('il_789c156110'),
  );
}

@RoutePage()
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthEvent.registrationFormOpened());
    });
  }

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext blocContext) async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    if (!blocContext.mounted) return;
    final request = RegisterRequest(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    blocContext.read<AuthBloc>().add(
          AuthEvent.registrationRequested(request),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          (p.registrationProgress != c.registrationProgress &&
              c.registrationProgress == ProgressStatus.success) ||
          (p.registrationProgress != c.registrationProgress &&
              c.registrationProgress == ProgressStatus.failure),
      listener: (context, state) {
        if (state.registrationProgress == ProgressStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('il_11506dbdb4')),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFF4caf50),
            ),
          );
          resolvePostAuthInitialRoute().then((route) {
            if (!context.mounted) return;
            context.router.replaceAll([route]);
          });
        } else if (state.registrationProgress == ProgressStatus.failure &&
            state.registrationFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _registrationErrorMessage(state.registrationFailure!),
              ),
            ),
          );
        }
      },
      builder: (blocContext, state) {
        final loading = state.registrationProgress == ProgressStatus.loading;
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
              child: GestureDetector(
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
                              onPressed: loading
                                  ? null
                                  : () => context.router.maybePop(),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              label: Text(
                                tr('back'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr('register'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('register_subtitle_email'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              enabled: !loading,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return tr('enter_email');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              enabled: !loading,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: tr('password'),
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return tr('enter_password');
                                }
                                if (value.length < 6) {
                                  return tr('il_2005290ddd');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              enabled: !loading,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: tr('confirm_password'),
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return tr('register_confirm_password_empty');
                                }
                                if (value != _passwordController.text) {
                                  return tr('passwords_dont_match');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4caf50),
                                  Color(0xFF66bb6a),
                                ],
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
                                  : () => _submit(blocContext),
                              child: loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      tr('il_61d30d997d'),
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
              ),
            ),
          ),
        );
      },
    );
  }
}
