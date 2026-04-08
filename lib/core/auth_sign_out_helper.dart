import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/auth/presentation/bloc/auth_state.dart';

/// Signs out through [AuthBloc] and waits until [AuthUnauthenticated] is emitted.
Future<void> signOutViaBlocAndWait(BuildContext context) async {
  final bloc = context.read<AuthBloc>();
  if (bloc.state is AuthUnauthenticated) return;
  bloc.add(const AuthSignOutRequested());
  await bloc.stream.firstWhere((s) => s is AuthUnauthenticated);
}
