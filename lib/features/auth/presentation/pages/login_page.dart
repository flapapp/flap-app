import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../router/app_router.dart';
import '../../../../router/post_auth_navigation.dart';
import '../../../../theme/flap_tokens.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_widgets.dart';

String _loginErrorMessage(Failure failure) {
  return failure.when(
    cache: () => tr('login_error'),
    network: (m) => m ?? tr('login_error'),
    unexpected: (m) => m ?? tr('login_error'),
    auth: (code, message) {
      switch (code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return tr('invalid_email_or_password');
        case 'too-many-requests':
          return tr('too_many_requests');
        default:
          return message ?? tr('login_error');
      }
    },
  );
}

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
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthEvent.loginFormOpened());
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            AuthEvent.loginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          (p.loginProgress != c.loginProgress &&
              c.loginProgress == ProgressStatus.success) ||
          (p.loginProgress != c.loginProgress &&
              c.loginProgress == ProgressStatus.failure),
      listener: (context, state) {
        if (state.loginProgress == ProgressStatus.success) {
          final route = state.postAuthNavigationRoute;
          if (route != null) {
            context.router.replaceAll([route]);
            return;
          }
          resolvePostAuthInitialRoute().then((r) {
            if (!context.mounted) return;
            context.router.replaceAll([r]);
          });
        } else if (state.loginProgress == ProgressStatus.failure &&
            state.loginFailure != null) {
          final failure = state.loginFailure!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'auth_error_with_detail',
                  namedArgs: {'detail': _loginErrorMessage(failure)},
                ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final loading = state.loginProgress == ProgressStatus.loading;
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            final focused = FocusScope.of(context);
            if (!focused.hasPrimaryFocus) focused.unfocus();
          },
          child: Scaffold(
            backgroundColor: FlapColors.bg,
            resizeToAvoidBottomInset: true,
            body: DecoratedBox(
              decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
              child: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Column(
                    children: [
                      // Head — back + language toggle.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AuthBackButton(
                              onTap: () => context.router.maybePop(),
                            ),
                            const AuthLangToggle(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                          children: [
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 18),
                                  AuthEyebrow(tr('auth_login_eyebrow')),
                                  const SizedBox(height: 12),
                                  Text(
                                    tr('auth_login_title').toUpperCase(),
                                    style: FlapText.cond(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 0.95,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    tr('auth_login_sub'),
                                    style: FlapText.sora(
                                      color: FlapColors.muted,
                                      fontSize: 14.5,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 26),
                                  AuthField(
                                    label: tr('email'),
                                    controller: _emailController,
                                    hint: tr('auth_email_ph'),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return tr('enter_email');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AuthField(
                                    label: tr('password'),
                                    controller: _passwordController,
                                    hint: '••••••••',
                                    obscure: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return tr('enter_password');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      AuthLink(
                                        tr('forgot_password'),
                                        onTap: () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(tr(
                                                  'password_recovery_later')),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Foot — CTA + swap.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 18, 28, 16),
                        child: Column(
                          children: [
                            AuthPrimaryButton(
                              label: tr('login'),
                              loading: loading,
                              onTap: _submit,
                            ),
                            const SizedBox(height: 18),
                            _swap(context, loading),
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
      },
    );
  }

  Widget _swap(BuildContext context, bool loading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          tr('auth_new_to_flap'),
          style: FlapText.sora(color: FlapColors.muted, fontSize: 14),
        ),
        const SizedBox(width: 5),
        AuthLink(
          tr('auth_sign_up'),
          onTap: loading
              ? () {}
              : () => context.router.push(const RegisterRoute()),
        ),
      ],
    );
  }
}
