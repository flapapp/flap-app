import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../../../features/auth/domain/usecases/delete_account_usecase.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';

@RoutePage()
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(sl<AppSettingsCubit>().load(forceRefresh: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _ProfileSettingsBody();
  }
}

class _ProfileSettingsBody extends StatelessWidget {
  const _ProfileSettingsBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppSettingsCubit, AppSettingsState>(
      listenWhen: (p, c) =>
          p.saveProgress != c.saveProgress || p.loadProgress != c.loadProgress,
      listener: (context, state) {
        if (state.saveProgress == ProgressStatus.success) {
          _showToast(context, tr('il_74a7f53bad'));
        }
        if (state.saveProgress == ProgressStatus.failure &&
            state.saveFailure != null) {
          _showToast(context, tr('il_c578b58288'), danger: true);
        }
      },
      builder: (context, state) {
        final loading = state.loadProgress == ProgressStatus.loading;
        final saving = state.saveProgress == ProgressStatus.loading;
        final saved = state.saveProgress == ProgressStatus.success;
        final prefs = state.effective;
        final cubit = context.read<AppSettingsCubit>();

        return Scaffold(
          backgroundColor: FlapColors.bg,
          appBar: AppBar(
            backgroundColor: FlapColors.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 4,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: FlapColors.text),
              onPressed: () => context.router.maybePop(),
            ),
            title: Text(
              tr('settings'),
              style: FlapText.sora(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            actions: [
              AnimatedOpacity(
                opacity: saved ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Row(
                    children: [
                      const Icon(Icons.check,
                          size: 14, color: FlapColors.greenBright),
                      const SizedBox(width: 5),
                      Text(
                        tr('settings_saved'),
                        style: FlapText.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FlapColors.greenBright,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: loading
              ? const FlapLoadingList(
                  itemCount: 6,
                  itemHeight: 60,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  gap: 12,
                  radius: 14,
                )
              : state.loadProgress == ProgressStatus.failure
                  ? _buildError(context, state, cubit)
                  : _buildContent(context, prefs, cubit, saving),
        );
      },
    );
  }

  Widget _buildError(
    BuildContext context,
    AppSettingsState state,
    AppSettingsCubit cubit,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.loadFailure?.toString() ?? '',
              textAlign: TextAlign.center,
              style: FlapText.sora(fontSize: 13, color: FlapColors.muted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => cubit.load(forceRefresh: true),
              child: Text(
                tr('il_942087cc2d'),
                style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.greenBright),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    dynamic prefs,
    AppSettingsCubit cubit,
    bool saving,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      children: [
        // ---- Preferences ----------------------------------------------------
        _label(tr('settings_preferences')),
        _toggleRow(
          icon: Icons.notifications_none_rounded,
          title: tr('il_682be64ae7'),
          subtitle: tr('il_79a518f1e6'),
          value: prefs.notificationsEnabled,
          onChanged: cubit.setNotificationsEnabled,
        ),
        _toggleRow(
          icon: Icons.play_circle_outline,
          title: tr('il_80bb8632c8'),
          subtitle: tr('il_b3b4d5549f'),
          value: prefs.autoplayVideos,
          onChanged: cubit.setAutoplayVideos,
        ),
        _toggleRow(
          icon: Icons.people_alt_outlined,
          title: tr('il_7f94fc6007'),
          subtitle: tr('il_d977efd0ad'),
          value: prefs.showOnlineStatus,
          onChanged: cubit.setShowOnlineStatus,
        ),
        _toggleRow(
          icon: Icons.person_add_alt,
          title: tr('il_4188679e07'),
          subtitle: tr('il_8f4daa5dea'),
          value: prefs.allowFriendRequests,
          onChanged: cubit.setAllowFriendRequests,
        ),

        // ---- Language -------------------------------------------------------
        _label(tr('settings_language_title')),
        _languageSeg(prefs.locale, cubit),

        // ---- Account --------------------------------------------------------
        _label(tr('settings_account')),
        _navRow(
          icon: Icons.edit_outlined,
          title: tr('il_15c4aa1303'),
          subtitle: tr('il_88fc14f702'),
          onTap: () => _openEditProfile(context),
        ),
        _navRow(
          icon: Icons.workspace_premium_outlined,
          title: tr('subscriptions_title'),
          subtitle: tr('manage_subscription'),
          onTap: () => context.router.push(const SubscriptionRoute()),
        ),

        // ---- Danger zone ----------------------------------------------------
        _label(tr('settings_danger_zone')),
        _navRow(
          icon: Icons.logout_rounded,
          title: tr('logout'),
          subtitle: tr('settings_logout_sub'),
          danger: true,
          showChevron: false,
          onTap: () => _confirmLogout(context),
        ),
        _navRow(
          icon: Icons.delete_outline_rounded,
          title: tr('settings_delete_account'),
          subtitle: tr('settings_delete_sub'),
          danger: true,
          showChevron: false,
          onTap: () => _confirmDelete(context),
        ),

        const SizedBox(height: 14),
        // ---- Save -----------------------------------------------------------
        _saveButton(cubit, saving),
        const SizedBox(height: 22),
        Center(
          child: Text(
            tr('settings_version'),
            style: FlapText.sora(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: FlapColors.muted2),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ widgets

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 11),
      child: Text(
        text.toUpperCase(),
        style: FlapText.sora(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FlapColors.muted,
        ).copyWith(letterSpacing: 1.1),
      ),
    );
  }

  Widget _rowShell({required Widget child, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: FlapColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlapColors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _iconTile(IconData icon, {bool danger = false}) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: danger
            ? FlapColors.red.withValues(alpha: 0.10)
            : FlapColors.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: danger
              ? FlapColors.red.withValues(alpha: 0.25)
              : FlapColors.border,
        ),
      ),
      child: Icon(icon,
          size: 18,
          color: danger ? FlapColors.red : FlapColors.greenBright),
    );
  }

  Widget _rowText(String title, String subtitle, {bool danger = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: FlapText.sora(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: danger ? FlapColors.red : FlapColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: FlapText.sora(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: FlapColors.muted),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _rowShell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          _iconTile(icon),
          const SizedBox(width: 13),
          Expanded(child: _rowText(title, subtitle)),
          const SizedBox(width: 10),
          _FlapSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
    bool showChevron = true,
  }) {
    return _rowShell(
      onTap: onTap,
      child: Row(
        children: [
          _iconTile(icon, danger: danger),
          const SizedBox(width: 13),
          Expanded(child: _rowText(title, subtitle, danger: danger)),
          if (showChevron)
            const Icon(Icons.chevron_right,
                size: 18, color: FlapColors.muted),
        ],
      ),
    );
  }

  Widget _languageSeg(String locale, AppSettingsCubit cubit) {
    final isUk = locale == 'uk';
    Widget option(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? FlapColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: FlapText.sora(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? FlapColors.text : FlapColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        children: [
          option(tr('welcome_language_ukrainian'), isUk,
              () => cubit.setLocale('uk')),
          const SizedBox(width: 4),
          option(tr('welcome_language_english'), !isUk,
              () => cubit.setLocale('en')),
        ],
      ),
    );
  }

  Widget _saveButton(AppSettingsCubit cubit, bool saving) {
    return Opacity(
      opacity: saving ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: saving ? null : cubit.save,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: FlapColors.primaryButton,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: FlapColors.green.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              saving ? tr('il_dc85af8f2b') : tr('save'),
              style: FlapText.sora(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: FlapColors.onGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ actions

  Future<void> _openEditProfile(BuildContext context) async {
    await context.router.push(ProfileCreationRoute(isEditing: true));
  }

  void _confirmLogout(BuildContext context) {
    _showConfirm(
      context,
      icon: Icons.logout_rounded,
      title: tr('logout_confirm'),
      body: tr('logout_confirm_body'),
      cta: tr('logout'),
      onConfirm: () async {
        await sl<AuthSessionRepository>().signOut();
        if (context.mounted) {
          context.router.replaceAll([const WelcomeRoute()]);
        }
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    _showConfirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: tr('settings_delete_title'),
      body: tr('settings_delete_body'),
      cta: tr('settings_delete_account'),
      onConfirm: () async {
        final router = context.router;
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context, rootNavigator: true);

        // Blocking progress while the RPC + cascades run.
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.55),
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: FlapColors.green),
          ),
        );

        final result = await sl<DeleteAccountUseCase>()();
        navigator.pop(); // dismiss the spinner

        result.when(
          success: (_) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  tr('settings_delete_requested'),
                  style: FlapText.sora(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: FlapColors.onGreen),
                ),
                backgroundColor: FlapColors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
            router.replaceAll([const WelcomeRoute()]);
          },
          failure: (_) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  tr('settings_delete_failed'),
                  style: FlapText.sora(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                backgroundColor: FlapColors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirm(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String cta,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: FlapColors.card,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: FlapColors.borderStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FlapColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                        color: FlapColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, size: 24, color: FlapColors.red),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style:
                      FlapText.sora(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: FlapText.sora(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: FlapColors.muted,
                  ).copyWith(height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogCtx).pop(),
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: FlapColors.surface2,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: FlapColors.borderStrong),
                          ),
                          child: Text(
                            tr('cancel'),
                            style: FlapText.sora(
                                fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(dialogCtx).pop();
                          onConfirm();
                        },
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFE37070), Color(0xFFC24A4A)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            cta,
                            style: FlapText.sora(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToast(BuildContext context, String message, {bool danger = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FlapText.sora(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: danger ? Colors.white : FlapColors.onGreen,
          ),
        ),
        backgroundColor: danger ? FlapColors.red : FlapColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Pill toggle matching the design `.sw` switch.
class _FlapSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlapSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: value ? FlapColors.green : const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: value ? Colors.transparent : FlapColors.border,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? FlapColors.onGreen : const Color(0xFFCDD4CE),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
