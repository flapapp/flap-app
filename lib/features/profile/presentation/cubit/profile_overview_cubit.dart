import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../../badges/data/models/badge.dart' as app_badge;
import '../../../teams/data/models/app_team.dart';
import '../../../teams/data/models/team_invite.dart';
import '../../domain/repositories/player_social_repository.dart';
import '../../domain/repositories/profile_team_membership_repository.dart';
import '../../domain/repositories/user_badges_repository.dart';

enum ProfileOverviewStatus { loading, ready, error }

class ProfileOverviewState {
  final ProfileOverviewStatus status;
  final String? userId;
  final List<app_badge.Badge> badges;
  final int friendsCount;
  final List<AppTeam> teams;
  final List<TeamInvite> invites;

  const ProfileOverviewState({
    required this.status,
    required this.userId,
    required this.badges,
    required this.friendsCount,
    required this.teams,
    required this.invites,
  });

  const ProfileOverviewState.initial()
    : status = ProfileOverviewStatus.loading,
      userId = null,
      badges = const [],
      friendsCount = 0,
      teams = const [],
      invites = const [];

  ProfileOverviewState copyWith({
    ProfileOverviewStatus? status,
    String? userId,
    List<app_badge.Badge>? badges,
    int? friendsCount,
    List<AppTeam>? teams,
    List<TeamInvite>? invites,
  }) {
    return ProfileOverviewState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      badges: badges ?? this.badges,
      friendsCount: friendsCount ?? this.friendsCount,
      teams: teams ?? this.teams,
      invites: invites ?? this.invites,
    );
  }
}

class ProfileOverviewCubit extends Cubit<ProfileOverviewState> {
  final AuthSessionRepository _authSessionRepository;
  final UserBadgesRepository _userBadgesRepository;
  final PlayerSocialRepository _playerSocialRepository;
  final ProfileTeamMembershipRepository _teamMembershipRepository;

  StreamSubscription<List<AppTeam>>? _teamsSubscription;
  StreamSubscription<List<TeamInvite>>? _invitesSubscription;

  ProfileOverviewCubit({
    required AuthSessionRepository authSessionRepository,
    required UserBadgesRepository userBadgesRepository,
    required PlayerSocialRepository playerSocialRepository,
    required ProfileTeamMembershipRepository teamMembershipRepository,
  }) : _authSessionRepository = authSessionRepository,
       _userBadgesRepository = userBadgesRepository,
       _playerSocialRepository = playerSocialRepository,
       _teamMembershipRepository = teamMembershipRepository,
       super(const ProfileOverviewState.initial());

  Future<void> initialize() async {
    final uid = _authSessionRepository.peekCurrentUser?.uid;
    if (uid == null) {
      emit(state.copyWith(status: ProfileOverviewStatus.ready));
      return;
    }

    emit(state.copyWith(status: ProfileOverviewStatus.loading, userId: uid));

    _teamsSubscription?.cancel();
    _invitesSubscription?.cancel();

    _teamsSubscription = _teamMembershipRepository
        .watchUserTeams(uid)
        .listen(
          (teams) => emit(
            state.copyWith(status: ProfileOverviewStatus.ready, teams: teams),
          ),
          onError: (_) =>
              emit(state.copyWith(status: ProfileOverviewStatus.error)),
        );

    _invitesSubscription = _teamMembershipRepository
        .watchInvites(uid)
        .listen(
          (invites) => emit(
            state.copyWith(
              status: ProfileOverviewStatus.ready,
              invites: invites,
            ),
          ),
          onError: (_) =>
              emit(state.copyWith(status: ProfileOverviewStatus.error)),
        );

    try {
      final results = await Future.wait<dynamic>([
        _userBadgesRepository.getUserBadges(uid),
        _playerSocialRepository.countFriends(uid),
      ]);
      emit(
        state.copyWith(
          status: ProfileOverviewStatus.ready,
          badges: results[0] as List<app_badge.Badge>,
          friendsCount: results[1] as int,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: ProfileOverviewStatus.error));
    }
  }

  @override
  Future<void> close() async {
    await _teamsSubscription?.cancel();
    await _invitesSubscription?.cancel();
    return super.close();
  }
}
