import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../router/app_router.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('il_74a7f53bad')),
              backgroundColor: const Color(0xFF4caf50),
            ),
          );
        }
        if (state.saveProgress == ProgressStatus.failure &&
            state.saveFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('il_c578b58288')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      builder: (context, state) {
        final loading = state.loadProgress == ProgressStatus.loading;
        final saving = state.saveProgress == ProgressStatus.loading;
        final prefs = state.effective;
        final cubit = context.read<AppSettingsCubit>();

        return Scaffold(
          backgroundColor: const Color(0xFF0f0f23),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0f0f23),
            elevation: 0,
            title: Text(
              tr('settings'),
              style: const TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                )
              : state.loadProgress == ProgressStatus.failure
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.loadFailure?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () =>
                                  cubit.load(forceRefresh: true),
                              child: Text(tr('il_942087cc2d')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSectionTitle(
                          context,
                          tr('il_c910d474dc'),
                          tr('il_1bbb5c650f'),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            onTap: () => _openEditProfile(context),
                            leading: const Icon(Icons.edit, color: Colors.white),
                            title: Text(
                              tr('il_15c4aa1303'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              tr('il_88fc14f702'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(
                          context,
                          tr('settings_language_title'),
                          tr('settings_language_subtitle'),
                        ),
                        const SizedBox(height: 12),
                        _buildLanguageToggle(context, prefs.locale, cubit),
                        const SizedBox(height: 12),
                        _buildSwitchTile(
                          title: tr('il_682be64ae7'),
                          subtitle: tr('il_79a518f1e6'),
                          value: prefs.notificationsEnabled,
                          onChanged: cubit.setNotificationsEnabled,
                        ),
                        _buildSwitchTile(
                          title: tr('il_80bb8632c8'),
                          subtitle: tr('il_b3b4d5549f'),
                          value: prefs.autoplayVideos,
                          onChanged: cubit.setAutoplayVideos,
                        ),
                        _buildSwitchTile(
                          title: tr('il_7f94fc6007'),
                          subtitle: tr('il_d977efd0ad'),
                          value: prefs.showOnlineStatus,
                          onChanged: cubit.setShowOnlineStatus,
                        ),
                        _buildSwitchTile(
                          title: tr('il_4188679e07'),
                          subtitle: tr('il_8f4daa5dea'),
                          value: prefs.allowFriendRequests,
                          onChanged: cubit.setAllowFriendRequests,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: saving ? null : cubit.save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4caf50),
                              disabledBackgroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              saving
                                  ? tr('il_dc85af8f2b')
                                  : tr('save'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    await context.router.push(ProfileCreationRoute(isEditing: true));
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageToggle(
    BuildContext context,
    String locale,
    AppSettingsCubit cubit,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLanguageOption(
              label: tr('welcome_language_ukrainian'),
              selected: locale == 'uk',
              onTap: () => cubit.setLocale('uk'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildLanguageOption(
              label: tr('welcome_language_english'),
              selected: locale == 'en',
              onTap: () => cubit.setLocale('en'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                  )
                : null,
            color: selected ? null : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.white70 : Colors.white24,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF4caf50),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
