import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme/flap_tokens.dart';

/// Legal document URLs surfaced from the auth flow.
const String kTermsUrl = 'https://flap.blog/terms';
const String kPrivacyUrl = 'https://flap.blog/privacy';

Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}

/// Design tokens local to the auth flow (`Flap Auth.html`).
class _Auth {
  _Auth._();
  static const double field = 54;
  // input background — rgba(255,255,255,.035)
  static const inputBg = Color(0x09FFFFFF);
  // focused input background tint — rgba(76,175,80,.06)
  static const inputBgFocus = Color(0x0F4CAF50);
}

/// UA / EN language toggle pill (top-right on every auth screen).
class AuthLangToggle extends StatelessWidget {
  const AuthLangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, label: 'УКР', code: 'uk', active: lang == 'uk'),
          _segment(context, label: 'EN', code: 'en', active: lang == 'en'),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required String code,
    required bool active,
  }) {
    return GestureDetector(
      onTap: () => context.setLocale(Locale(code)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? FlapColors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: FlapText.cond(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.7,
            color: active ? const Color(0xFF0A0D0B) : FlapColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Tracked green-bright uppercase eyebrow label.
class AuthEyebrow extends StatelessWidget {
  const AuthEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: FlapText.cond(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 4.4,
        color: FlapColors.greenBright,
      ),
    );
  }
}

/// 42px glass back button (`.iconbtn`).
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: FlapColors.border),
        ),
        child: const Icon(Icons.chevron_left, color: FlapColors.text, size: 22),
      ),
    );
  }
}

/// Labeled input field with focus glow + optional password eye toggle.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focusNode = FocusNode();
  bool _focused = false;
  late bool _obscured = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: FlapText.sora(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: FlapColors.muted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 9),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: _Auth.field,
          decoration: BoxDecoration(
            color: _focused ? _Auth.inputBgFocus : _Auth.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? FlapColors.green : FlapColors.border,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: FlapColors.green.withValues(alpha: 0.16),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  obscureText: _obscured,
                  keyboardType: widget.keyboardType,
                  autocorrect: false,
                  validator: widget.validator,
                  cursorColor: FlapColors.greenBright,
                  style: FlapText.sora(color: FlapColors.text, fontSize: 15),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: widget.hint,
                    hintStyle:
                        FlapText.sora(color: FlapColors.muted2, fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                    contentPadding: EdgeInsets.fromLTRB(
                        16, 0, widget.obscure ? 4 : 16, 0),
                  ),
                ),
              ),
              if (widget.obscure)
                GestureDetector(
                  onTap: () => setState(() => _obscured = !_obscured),
                  child: Container(
                    width: 46,
                    height: _Auth.field,
                    alignment: Alignment.center,
                    child: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: FlapColors.muted,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Inline error text under a field (validation surfaced manually).
class AuthFieldError extends StatelessWidget {
  const AuthFieldError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox(height: 0);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        message!,
        style: FlapText.sora(color: const Color(0xFFFF8A8A), fontSize: 12),
      ),
    );
  }
}

/// The 20px square check box used by [AuthCheckbox] and standalone (e.g. when
/// the adjacent label has its own tap targets).
class AuthCheckSquare extends StatelessWidget {
  const AuthCheckSquare({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value ? FlapColors.green : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? FlapColors.green : FlapColors.borderStrong,
          width: 1.6,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, color: FlapColors.onGreen, size: 14)
          : null,
    );
  }
}

/// Square checkbox + label (remember-me / agree-to-terms).
class AuthCheckbox extends StatelessWidget {
  const AuthCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
    this.crossStart = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final bool crossStart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment:
            crossStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthCheckSquare(value: value),
          const SizedBox(width: 9),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Primary gradient CTA with trailing arrow and loading state.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: FlapColors.primaryButton,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: FlapColors.green.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(FlapColors.onGreen),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: FlapText.sora(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: FlapColors.onGreen,
                    ),
                  ),
                  if (showArrow) ...[
                    const SizedBox(width: 9),
                    const Icon(Icons.arrow_forward_rounded,
                        color: FlapColors.onGreen, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Ghost / secondary glass button.
class AuthGhostButton extends StatelessWidget {
  const AuthGhostButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlapColors.borderStrong),
        ),
        child: Text(
          label,
          style: FlapText.sora(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: FlapColors.text,
          ),
        ),
      ),
    );
  }
}

/// Inline "… Terms and Privacy Policy …" text where the Terms and Privacy
/// words open their respective external URLs. Used for the welcome legal line
/// and the register terms-agreement label.
class LegalAgreementText extends StatefulWidget {
  const LegalAgreementText({
    super.key,
    required this.prefix,
    required this.connector,
    required this.baseStyle,
    required this.linkStyle,
    this.suffix = '',
    this.textAlign = TextAlign.start,
  });

  final String prefix;
  final String connector;
  final String suffix;
  final TextStyle baseStyle;
  final TextStyle linkStyle;
  final TextAlign textAlign;

  @override
  State<LegalAgreementText> createState() => _LegalAgreementTextState();
}

class _LegalAgreementTextState extends State<LegalAgreementText> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => openExternalUrl(kTermsUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => openExternalUrl(kPrivacyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${widget.prefix} '),
          TextSpan(
            text: tr('auth_terms'),
            style: widget.linkStyle,
            recognizer: _termsTap,
          ),
          TextSpan(text: ' ${widget.connector} '),
          TextSpan(
            text: tr('auth_privacy'),
            style: widget.linkStyle,
            recognizer: _privacyTap,
          ),
          if (widget.suffix.isNotEmpty) TextSpan(text: widget.suffix),
        ],
      ),
      textAlign: widget.textAlign,
      style: widget.baseStyle,
    );
  }
}

/// Small green-bright text link.
class AuthLink extends StatelessWidget {
  const AuthLink(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: FlapText.sora(
          color: FlapColors.greenBright,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
