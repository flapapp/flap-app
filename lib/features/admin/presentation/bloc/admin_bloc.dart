import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/admin_failure.dart';
import '../../domain/repositories/admin_repository.dart';
import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc(this._repository) : super(const AdminInitial()) {
    on<AdminDeleteAllChallengesRequested>(_onDeleteAllChallengesRequested);
  }

  final AdminRepository _repository;

  Future<void> _onDeleteAllChallengesRequested(
    AdminDeleteAllChallengesRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(const AdminActionInProgress());
    try {
      await _repository.deleteAllChallengesAndSubmissions();
      emit(const AdminDeleteSuccess());
      emit(const AdminInitial());
    } on AdminFailure catch (e) {
      emit(AdminDeleteFailure(code: e.code, message: e.message));
      emit(const AdminInitial());
    } catch (e) {
      emit(AdminDeleteFailure(code: 'unknown', message: e.toString()));
      emit(const AdminInitial());
    }
  }
}
