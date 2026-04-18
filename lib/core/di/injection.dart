import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/auth/data/datasources/auth_session_remote_datasource.dart';
import '../../features/auth/data/datasources/auth_session_remote_datasource_impl.dart';
import '../../features/auth/data/datasources/intro_local_datasource.dart';
import '../../features/auth/data/datasources/intro_local_datasource_impl.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/auth_session_repository_impl.dart';
import '../../features/auth/data/repositories/intro_settings_repository_impl.dart';
import '../../features/auth/data/integrations/post_login_actions_impl.dart';
import '../../features/auth/domain/contracts/post_login_actions.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../features/auth/domain/repositories/intro_settings_repository.dart';
import '../../features/auth/domain/usecases/check_intro_completed_usecase.dart';
import '../../features/auth/domain/usecases/mark_intro_completed_usecase.dart';
import '../../features/auth/domain/usecases/register_new_user_usecase.dart';
import '../../features/auth/domain/usecases/resolve_startup_navigation_usecase.dart';
import '../../features/badges/data/repositories/badges_repository_impl.dart';
import '../../features/badges/domain/repositories/badges_repository.dart';
import '../../features/auth/domain/usecases/sign_in_with_email_usecase.dart';
import '../../features/challenges/data/repositories/challenges_repository_impl.dart';
import '../../features/challenges/domain/repositories/challenges_repository.dart';
import '../../features/friends/data/repositories/friends_repository_impl.dart';
import '../../features/friends/domain/repositories/friends_repository.dart';
import '../../features/ratings/data/repositories/ratings_repository_impl.dart';
import '../../features/ratings/domain/repositories/ratings_repository.dart';
import '../../features/matches/data/datasources/matches_read_remote_datasource.dart';
import '../../features/matches/data/datasources/matches_read_remote_datasource_impl.dart';
import '../../features/matches/data/repositories/matches_repository_impl.dart';
import '../../features/matches/domain/repositories/matches_repository.dart';
import '../../services/challenge_service.dart';
import '../../services/match_service.dart';
import '../../features/profile/data/datasources/match_participation_stats_remote_datasource.dart';
import '../../features/profile/data/datasources/match_participation_stats_remote_datasource_impl.dart';
import '../../features/profile/data/datasources/player_videos_remote_datasource.dart';
import '../../features/profile/data/datasources/player_videos_remote_datasource_impl.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/datasources/profile_remote_datasource_impl.dart';
import '../../features/profile/data/datasources/profile_storage_datasource.dart';
import '../../features/profile/data/datasources/profile_storage_datasource_impl.dart';
import '../../features/profile/data/datasources/team_stats_remote_datasource.dart';
import '../../features/profile/data/datasources/team_stats_remote_datasource_impl.dart';
import '../../features/profile/data/repositories/current_user_profile_avatar_repository_impl.dart';
import '../../features/profile/data/repositories/match_participation_stats_repository_impl.dart';
import '../../features/profile/data/repositories/player_badge_endorsement_repository_impl.dart';
import '../../features/profile/data/repositories/player_challenge_invite_repository_impl.dart';
import '../../features/profile/data/repositories/player_notification_actions_repository_impl.dart';
import '../../features/profile/data/repositories/player_profile_dashboard_repository_impl.dart';
import '../../features/profile/data/repositories/player_social_repository_impl.dart';
import '../../features/profile/data/repositories/player_videos_repository_impl.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/data/repositories/profile_team_membership_repository_impl.dart';
import '../../features/profile/data/repositories/team_stats_repository_impl.dart';
import '../../features/profile/data/repositories/user_badges_repository_impl.dart';
import '../../features/profile/domain/repositories/current_user_profile_avatar_repository.dart';
import '../../features/profile/domain/repositories/match_participation_stats_repository.dart';
import '../../features/profile/domain/repositories/player_badge_endorsement_repository.dart';
import '../../features/profile/domain/repositories/player_challenge_invite_repository.dart';
import '../../features/profile/domain/repositories/player_notification_actions_repository.dart';
import '../../features/profile/domain/repositories/player_profile_dashboard_repository.dart';
import '../../features/profile/domain/repositories/player_social_repository.dart';
import '../../features/profile/domain/repositories/player_videos_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/repositories/profile_team_membership_repository.dart';
import '../../features/profile/domain/repositories/team_stats_repository.dart';
import '../../features/profile/domain/repositories/user_badges_repository.dart';
import '../../features/profile/domain/usecases/commit_profile_avatar_urls_usecase.dart';
import '../../features/profile/domain/usecases/dismiss_donation_prompt_usecase.dart';
import '../../features/profile/domain/usecases/load_current_profile_usecase.dart';
import '../../features/profile/domain/usecases/load_player_profile_dashboard_usecase.dart';
import '../../features/profile/domain/usecases/save_app_settings_usecase.dart';
import '../../features/profile/domain/usecases/submit_editable_profile_usecase.dart';
import '../../services/badge_service.dart';
import '../../services/friends_service.dart';
import '../../services/notification_service.dart';
import '../../services/rating_service.dart';
import '../../services/subscription_service.dart';
import '../../services/team_service.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/profile/presentation/cubit/profile_creation_cubit.dart';
import '../../features/profile/presentation/cubit/profile_settings_cubit.dart';
import '../../features/stats/data/repositories/stats_repository_impl.dart';
import '../../features/stats/domain/repositories/stats_repository.dart';
import '../../features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import '../../features/subscriptions/domain/repositories/subscriptions_repository.dart';
import '../../features/teams/data/datasources/teams_remote_datasource.dart';
import '../../features/teams/data/datasources/teams_remote_datasource_impl.dart';
import '../../features/teams/data/repositories/teams_repository_impl.dart';
import '../../features/teams/domain/repositories/teams_repository.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl
    ..registerLazySingleton<AuthSessionRemoteDataSource>(
      AuthSessionRemoteDataSourceImpl.new,
    )
    ..registerLazySingleton<IntroLocalDataSource>(
      IntroLocalDataSourceImpl.new,
    )
    ..registerLazySingleton<AuthSessionRepository>(
      () => AuthSessionRepositoryImpl(sl()),
    )
    ..registerLazySingleton<IntroSettingsRepository>(
      () => IntroSettingsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      AuthRepositoryImpl.new,
    )
    ..registerLazySingleton<PostLoginActions>(
      PostLoginActionsImpl.new,
    )
    ..registerLazySingleton(
      () => SignInWithEmailUseCase(sl()),
    )
    ..registerLazySingleton(
      () => RegisterNewUserUseCase(sl()),
    )
    ..registerLazySingleton(
      () => ResolveStartupNavigationUseCase(sl(), sl()),
    )
    ..registerLazySingleton(
      () => MarkIntroCompletedUseCase(sl()),
    )
    ..registerLazySingleton(
      () => CheckIntroCompletedUseCase(sl()),
    )
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<ProfileStorageDataSource>(
      () => ProfileStorageDataSourceImpl(FirebaseStorage.instance),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton(
      () => DismissDonationPromptUseCase(sl()),
    )
    ..registerLazySingleton(
      () => LoadCurrentProfileUseCase(sl(), sl()),
    )
    ..registerLazySingleton(
      () => SaveAppSettingsUseCase(sl(), sl()),
    )
    ..registerLazySingleton(
      () => CommitProfileAvatarUrlsUseCase(sl(), sl()),
    )
    ..registerLazySingleton(
      () => SubmitEditableProfileUseCase(sl()),
    )
    ..registerFactory(
      () => ProfileBloc(sl(), sl(), sl(), sl()),
    )
    ..registerFactory(
      () => ProfileSettingsCubit(sl(), sl()),
    )
    ..registerFactory(
      () => ProfileCreationCubit(sl()),
    )
    ..registerLazySingleton<MatchParticipationStatsRemoteDataSource>(
      () => MatchParticipationStatsRemoteDataSourceImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<PlayerVideosRemoteDataSource>(
      () => PlayerVideosRemoteDataSourceImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<TeamStatsRemoteDataSource>(
      () => TeamStatsRemoteDataSourceImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<PlayerVideosRepository>(
      () => PlayerVideosRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton<TeamStatsRepository>(
      () => TeamStatsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<TeamsRemoteDataSource>(
      () => TeamsRemoteDataSourceImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<TeamService>(() => TeamService())
    ..registerLazySingleton<TeamsRepository>(
      () => TeamsRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton<MatchesReadRemoteDataSource>(
      () => MatchesReadRemoteDataSourceImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<MatchService>(() => MatchService())
    ..registerLazySingleton<MatchesRepository>(
      () => MatchesRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton<ChallengeService>(() => ChallengeService())
    ..registerLazySingleton<ChallengesRepository>(
      () => ChallengesRepositoryImpl(sl()),
    )
    ..registerLazySingleton<RatingService>(() => RatingService())
    ..registerLazySingleton<RatingsRepository>(
      () => RatingsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<BadgeService>(BadgeService.new)
    ..registerLazySingleton<BadgesRepository>(
      () => BadgesRepositoryImpl(sl()),
    )
    ..registerLazySingleton<SubscriptionService>(() => SubscriptionService())
    ..registerLazySingleton<SubscriptionsRepository>(
      () => SubscriptionsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<StatsRepository>(
      () => StatsRepositoryImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<AdminRepository>(
      () => AdminRepositoryImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<MatchParticipationStatsRepository>(
      () => MatchParticipationStatsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<UserBadgesRepository>(
      () => UserBadgesRepositoryImpl(sl<BadgesRepository>()),
    )
    ..registerLazySingleton<ProfileTeamMembershipRepository>(
      () => ProfileTeamMembershipRepositoryImpl(sl<TeamsRepository>()),
    )
    ..registerLazySingleton<PlayerProfileDashboardRepository>(
      () => PlayerProfileDashboardRepositoryImpl(
        sl(),
        sl(),
        sl(),
        sl(),
        sl(),
      ),
    )
    ..registerLazySingleton<FriendsService>(FriendsService.new)
    ..registerLazySingleton<FriendsRepository>(
      () => FriendsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<PlayerSocialRepository>(
      () => PlayerSocialRepositoryImpl(sl<FriendsRepository>()),
    )
    ..registerLazySingleton<PlayerBadgeEndorsementRepository>(
      () => PlayerBadgeEndorsementRepositoryImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<NotificationService>(NotificationService.new)
    ..registerLazySingleton<PlayerNotificationActionsRepository>(
      () => PlayerNotificationActionsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<PlayerChallengeInviteRepository>(
      () => PlayerChallengeInviteRepositoryImpl(FirebaseFirestore.instance),
    )
    ..registerLazySingleton<CurrentUserProfileAvatarRepository>(
      () => CurrentUserProfileAvatarRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton(
      () => LoadPlayerProfileDashboardUseCase(sl()),
    );
}
