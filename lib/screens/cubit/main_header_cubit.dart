import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/notifications/data/services/notification_service.dart';

enum MainHeaderStatus { loading, ready, error }

class MainHeaderState {
  final MainHeaderStatus status;
  final Map<String, dynamic>? profileData;
  final int unreadCount;

  const MainHeaderState({
    required this.status,
    required this.profileData,
    required this.unreadCount,
  });

  const MainHeaderState.initial()
    : status = MainHeaderStatus.loading,
      profileData = null,
      unreadCount = 0;

  MainHeaderState copyWith({
    MainHeaderStatus? status,
    Map<String, dynamic>? profileData,
    int? unreadCount,
  }) {
    return MainHeaderState(
      status: status ?? this.status,
      profileData: profileData ?? this.profileData,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class MainHeaderCubit extends Cubit<MainHeaderState> {
  final SupabaseClient _supabase;
  final NotificationService _notificationService;
  final String _userId;

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<int>? _unreadSubscription;

  MainHeaderCubit({
    required SupabaseClient supabase,
    required NotificationService notificationService,
    required String userId,
  }) : _supabase = supabase,
       _notificationService = notificationService,
       _userId = userId,
       super(const MainHeaderState.initial());

  void initialize() {
    _profileSubscription?.cancel();
    _unreadSubscription?.cancel();

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _userId)
        .listen(
          (rows) {
            final profile = rows.isNotEmpty ? rows.first : null;
            emit(
              state.copyWith(
                status: MainHeaderStatus.ready,
                profileData: profile,
              ),
            );
          },
          onError: (_) => emit(state.copyWith(status: MainHeaderStatus.error)),
        );

    _unreadSubscription = _notificationService.getUnreadCount().listen(
      (count) => emit(
        state.copyWith(status: MainHeaderStatus.ready, unreadCount: count),
      ),
      onError: (_) => emit(state.copyWith(status: MainHeaderStatus.error)),
    );
  }

  @override
  Future<void> close() async {
    await _profileSubscription?.cancel();
    await _unreadSubscription?.cancel();
    return super.close();
  }
}
