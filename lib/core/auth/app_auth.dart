import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/injection.dart';
import '../interactions/interaction_store.dart';
import '../interactions/user_rating_store.dart';
import '../settings/app_settings_cubit.dart';
import '../../features/notifications/data/services/notification_service.dart';
import '../../features/profile/data/services/user_settings_service.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/subscriptions/domain/subscription_access.dart';
import '../../widgets/team_crest.dart';
import '../../widgets/video_preview_box.dart';

/// Session helpers backed by Supabase Auth (UUID user ids aligned with `profiles.id`).
abstract final class AppAuth {
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static String? get currentUserEmail => currentUser?.email;

  static Stream<AuthState> get onAuthStateChange =>
      Supabase.instance.client.auth.onAuthStateChange;

  /// Single source of truth for signing out. Revokes this device's push token,
  /// ends the Supabase session (which clears the persisted auth token from local
  /// storage), and wipes every in-memory store, cache and bloc that holds data
  /// scoped to the user who just left — so nothing leaks into the next session.
  static Future<void> signOut() async {
    // 1. Revoke the device's push tokens *before* the session is torn down — the
    //    revoke needs a valid user id, which becomes null after signOut().
    await _guardAsync(() async {
      if (sl.isRegistered<NotificationService>()) {
        await sl<NotificationService>().revokePushTokensForCurrentUser();
      }
    });

    // 2. End the Supabase session. This clears the persisted session/refresh
    //    token from supabase_flutter's local storage.
    await Supabase.instance.client.auth.signOut();

    // 3. Wipe all user-scoped in-memory state so the next user starts clean.
    _clearUserScopedState();
  }

  /// Clears every singleton store / cache / bloc that caches per-user data.
  /// Stateless services (TeamService, MatchService) and screen-scoped cubits
  /// (MatchesListCubit, ProfileOverviewCubit) are intentionally omitted: they
  /// hold no cross-session state or are disposed when the UI is torn down.
  static void _clearUserScopedState() {
    // Reactive per-content / per-user interaction stores.
    _guard(() {
      if (sl.isRegistered<InteractionStore>()) sl<InteractionStore>().clear();
    });
    _guard(() {
      if (sl.isRegistered<UserRatingStore>()) sl<UserRatingStore>().clear();
    });

    // Cached settings/preferences.
    _guard(() {
      if (sl.isRegistered<UserSettingsService>()) {
        sl<UserSettingsService>().invalidateCache();
      }
    });
    _guard(() {
      if (sl.isRegistered<AppSettingsCubit>()) sl<AppSettingsCubit>().reset();
    });

    // ProfileBloc is a lazy singleton holding the previous user's profile in its
    // state. Resetting the registration drops that state; the next access builds
    // a fresh bloc with the initial (empty) state.
    _guard(() {
      if (sl.isRegistered<ProfileBloc>()) sl.resetLazySingleton<ProfileBloc>();
    });

    // Cached premium-access state — must clear or the next user inherits it.
    _guard(() {
      if (sl.isRegistered<SubscriptionAccess>()) {
        sl<SubscriptionAccess>().clear();
      }
    });

    // Static image caches that may hold other users' / teams' content.
    _guard(TeamCrest.clearCache);
    _guard(VideoPreviewBox.clearThumbCache);
  }

  static void _guard(void Function() fn) {
    try {
      fn();
    } catch (e, st) {
      developer.log('signOut cleanup step failed',
          name: 'AppAuth', error: e, stackTrace: st);
    }
  }

  static Future<void> _guardAsync(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e, st) {
      developer.log('signOut cleanup step failed',
          name: 'AppAuth', error: e, stackTrace: st);
    }
  }
}
