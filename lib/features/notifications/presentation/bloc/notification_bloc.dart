import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/notification.dart';
import '../../domain/repositories/notifications_repository.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc(this._repository) : super(const NotificationLoading()) {
    on<NotificationStarted>(_onStarted);
    on<NotificationUpdated>(_onUpdated);
    on<NotificationMarkReadRequested>(_onMarkReadRequested);
    on<NotificationMarkAllReadRequested>(_onMarkAllReadRequested);
    on<NotificationDeleteRequested>(_onDeleteRequested);
  }

  final NotificationsRepository _repository;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;

  Future<void> _onStarted(
    NotificationStarted event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());
    await _notificationsSubscription?.cancel();
    _notificationsSubscription = _repository.getUserNotifications().listen(
      (notifications) => add(NotificationUpdated(notifications)),
      onError: (error) => emit(NotificationError(error.toString())),
    );
  }

  void _onUpdated(
    NotificationUpdated event,
    Emitter<NotificationState> emit,
  ) {
    emit(NotificationLoaded(event.notifications));
  }

  Future<void> _onMarkReadRequested(
    NotificationMarkReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is NotificationLoaded) {
      emit(
        NotificationLoaded(
          current.notifications
              .map(
                (n) => n.id == event.notificationId
                    ? n.copyWith(isRead: true)
                    : n,
              )
              .toList(),
        ),
      );
    }
    await _repository.markAsRead(event.notificationId);
  }

  Future<void> _onMarkAllReadRequested(
    NotificationMarkAllReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is NotificationLoaded) {
      emit(
        NotificationLoaded(
          current.notifications
              .map((n) => n.copyWith(isRead: true))
              .toList(),
        ),
      );
    }
    await _repository.markAllAsRead();
  }

  Future<void> _onDeleteRequested(
    NotificationDeleteRequested event,
    Emitter<NotificationState> emit,
  ) async {
    await _repository.deleteNotification(event.notificationId);
  }

  @override
  Future<void> close() async {
    await _notificationsSubscription?.cancel();
    return super.close();
  }
}
