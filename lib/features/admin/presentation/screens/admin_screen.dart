import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:flap_app/utils/i18n.dart';

import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

@RoutePage()
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminBloc(context.read<AdminRepository>()),
      child: const _AdminView(),
    );
  }
}

class _AdminView extends StatelessWidget {
  const _AdminView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (prev, curr) =>
          curr is AdminDeleteSuccess || curr is AdminDeleteFailure,
      listener: (context, state) {
        if (state is AdminDeleteSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline(
                  '✅ Всі челенджі видалено!',
                  '✅ All challenges deleted!',
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is AdminDeleteFailure) {
          final msg = state.message ?? state.code;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline('❌ Помилка: $msg', '❌ Error: $msg'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          backgroundColor: const Color(0xFF0f0f23),
        ),
        backgroundColor: const Color(0xFF0f0f23),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Text(
                  I18n.inline('Адміністрування', 'Administration'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                BlocBuilder<AdminBloc, AdminState>(
                  buildWhen: (prev, curr) =>
                      curr is AdminInitial ||
                      curr is AdminActionInProgress ||
                      curr is AdminDeleteFailure,
                  builder: (context, state) {
                    final deleting = state is AdminActionInProgress;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: deleting
                            ? null
                            : () => context.read<AdminBloc>().add(
                                  const AdminDeleteAllChallengesRequested(),
                                ),
                        icon: deleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_forever),
                        label: Text(
                          deleting
                              ? I18n.inline('Видаляю...', 'Deleting...')
                              : I18n.inline(
                                  'Видалити всі челенджі',
                                  'Delete all challenges',
                                ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
