import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/models/notification.dart';

import '../../domain/usecases/notifications_usecases.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc(this._useCases) : super(const NotificationsInitial()) {
    on<NotificationsStarted>(_onStarted);
    on<NotificationsListUpdated>(_onListUpdated);
    on<NotificationMarkReadRequested>(_onMarkRead);
    on<NotificationDeleteRequested>(_onDelete);
    on<NotificationsMarkAllReadRequested>(_onMarkAllRead);
  }

  final NotificationsUseCases _useCases;
  StreamSubscription<List<AppNotification>>? _sub;

  Future<void> _onStarted(
    NotificationsStarted event,
    Emitter<NotificationsState> emit,
  ) async {
    await _sub?.cancel();
    emit(const NotificationsReady(notifications: []));

    final uid = AppAuthContext.userId;
    if (uid == null) {
      return;
    }

    _sub = _useCases.watchForUser(uid).listen(
      (list) => add(NotificationsListUpdated(list)),
      onError: (Object e, StackTrace _) {
        final cur = state;
        if (cur is NotificationsReady) {
          emit(cur.copyWith(errorMessage: e.toString()));
        }
      },
    );
  }

  void _onListUpdated(
    NotificationsListUpdated event,
    Emitter<NotificationsState> emit,
  ) {
    emit(NotificationsReady(notifications: event.items));
  }

  Future<void> _onMarkRead(
    NotificationMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    await _useCases.markAsRead(event.id);
  }

  Future<void> _onDelete(
    NotificationDeleteRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    await _useCases.delete(event.id);
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final uid = AppAuthContext.userId;
    if (uid == null) return;
    await _useCases.markAllAsRead(uid);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
