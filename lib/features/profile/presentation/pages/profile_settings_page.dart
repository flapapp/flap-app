import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../../core/progress/progress_status.dart';
import 'profile_creation_page.dart';
import '../../../../utils/i18n.dart';
import '../cubit/profile_settings_cubit.dart';

@RoutePage()
class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileSettingsCubit>()..load(),
      child: const _ProfileSettingsBody(),
    );
  }
}

class _ProfileSettingsBody extends StatelessWidget {
  const _ProfileSettingsBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileSettingsCubit, ProfileSettingsState>(
      listenWhen: (p, c) =>
          p.saveProgress != c.saveProgress || p.loadProgress != c.loadProgress,
      listener: (context, state) {
        if (state.saveProgress == ProgressStatus.success) {
          unawaited(sl<NotificationService>().initialize());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline('Налаштування збережено', 'Settings saved'),
              ),
              backgroundColor: const Color(0xFF4caf50),
            ),
          );
        }
        if (state.saveProgress == ProgressStatus.failure &&
            state.saveFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline(
                  'Не вдалося зберегти налаштування',
                  'Unable to save settings',
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      builder: (context, state) {
        final loading = state.loadProgress == ProgressStatus.loading;
        final saving = state.saveProgress == ProgressStatus.loading;

        return Scaffold(
          backgroundColor: const Color(0xFF0f0f23),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0f0f23),
            elevation: 0,
            title: Text(
              I18n.t('settings'),
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
                                  context.read<ProfileSettingsCubit>().load(),
                              child: Text(I18n.inline('Повторити', 'Retry')),
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
                      I18n.inline('Основні', 'General'),
                      I18n.inline(
                        'Керуйте базовими параметрами профілю',
                        'Manage basic profile preferences',
                      ),
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
                          I18n.inline('Редагувати профіль', 'Edit profile'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          I18n.inline(
                            'Змінити аватар і дані про себе',
                            'Change avatar and personal data',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    _buildSwitchTile(
                      title: I18n.inline(
                        'Увімкнути сповіщення',
                        'Enable notifications',
                      ),
                      subtitle: I18n.inline(
                        'Отримувати системні та соціальні сповіщення',
                        'Receive system and social notifications',
                      ),
                      value: state.notificationsEnabled,
                      onChanged: (v) => context
                          .read<ProfileSettingsCubit>()
                          .setNotificationsEnabled(v),
                    ),
                    _buildSwitchTile(
                      title: I18n.inline(
                        'Автовідтворення відео',
                        'Autoplay videos',
                      ),
                      subtitle: I18n.inline(
                        'Автоматично запускати відео на екранах перегляду',
                        'Automatically start videos on viewing screens',
                      ),
                      value: state.autoplayVideos,
                      onChanged: (v) =>
                          context.read<ProfileSettingsCubit>().setAutoplayVideos(v),
                    ),
                    _buildSwitchTile(
                      title: I18n.inline(
                        'Показувати онлайн-статус',
                        'Show online status',
                      ),
                      subtitle: I18n.inline(
                        'Дозволити іншим бачити вашу активність',
                        'Allow others to see your activity',
                      ),
                      value: state.showOnlineStatus,
                      onChanged: (v) =>
                          context.read<ProfileSettingsCubit>().setShowOnlineStatus(v),
                    ),
                    _buildSwitchTile(
                      title: I18n.inline(
                        'Дозволити запити в друзі',
                        'Allow friend requests',
                      ),
                      subtitle: I18n.inline(
                        'Інші гравці зможуть надсилати запити',
                        'Other players will be able to send requests',
                      ),
                      value: state.allowFriendRequests,
                      onChanged: (v) => context
                          .read<ProfileSettingsCubit>()
                          .setAllowFriendRequests(v),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () =>
                                context.read<ProfileSettingsCubit>().save(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
                          disabledBackgroundColor: Colors.white24,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          saving
                              ? I18n.inline('Зберігаємо...', 'Saving...')
                              : I18n.t('save'),
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProfileCreationScreen(isEditing: true),
      ),
    );
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
