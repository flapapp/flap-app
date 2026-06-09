import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../router/post_auth_navigation.dart';
import '../../../../theme/flap_tokens.dart';
import '../../domain/entities/register_request.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_widgets.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agree = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthEvent.registrationFormOpened());
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext blocContext) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('auth_must_agree'))),
      );
      return;
    }
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
              backgroundColor: FlapColors.green,
            ),
          );
          final route = state.postAuthNavigationRoute;
          if (route != null) {
            context.router.replaceAll([route]);
          } else {
            resolvePostAuthInitialRoute().then((r) {
              if (!context.mounted) return;
              context.router.replaceAll([r]);
            });
          }
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
                              onTap: loading
                                  ? () {}
                                  : () => context.router.maybePop(),
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
                                  AuthEyebrow(tr('auth_register_eyebrow')),
                                  const SizedBox(height: 12),
                                  Text(
                                    tr('auth_register_title').toUpperCase(),
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
                                    tr('auth_register_sub'),
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
                                    enabled: !loading,
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
                                    enabled: !loading,
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
                                  const SizedBox(height: 16),
                                  AuthField(
                                    label: tr('confirm_password'),
                                    controller: _confirmPasswordController,
                                    hint: '••••••••',
                                    obscure: true,
                                    enabled: !loading,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return tr(
                                            'register_confirm_password_empty');
                                      }
                                      if (value != _passwordController.text) {
                                        return tr('passwords_dont_match');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () =>
                                            setState(() => _agree = !_agree),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              top: 1, right: 9),
                                          child: AuthCheckSquare(value: _agree),
                                        ),
                                      ),
                                      Expanded(child: _termsLabel()),
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
                              label: tr('register'),
                              loading: loading,
                              onTap: () => _submit(blocContext),
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

  Widget _termsLabel() {
    return LegalAgreementText(
      prefix: tr('auth_agree_a'),
      connector: tr('auth_agree_and'),
      baseStyle: FlapText.sora(
        color: FlapColors.muted,
        fontSize: 12.5,
        height: 1.5,
      ),
      linkStyle: FlapText.sora(
        color: FlapColors.text,
        fontSize: 12.5,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _swap(BuildContext context, bool loading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          tr('auth_have_account'),
          style: FlapText.sora(color: FlapColors.muted, fontSize: 14),
        ),
        const SizedBox(width: 5),
        AuthLink(
          tr('auth_sign_in'),
          onTap: loading ? () {} : () => context.router.maybePop(),
        ),
      ],
    );
  }
}
