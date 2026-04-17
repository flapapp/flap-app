import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flap_app/core/di/injection.dart';
import 'package:flap_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flap_app/features/auth/presentation/pages/login_page.dart';
import 'package:flap_app/router/app_router.dart';
import 'package:flap_app/utils/i18n.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await sl.reset();
    await configureDependencies();
  });

  testWidgets('Welcome screen renders and navigates to Login', (WidgetTester tester) async {
    I18n.setLanguage('uk');
    final router = AppRouter();
    await tester.pumpWidget(
      BlocProvider<AuthBloc>(
        create: (_) => AuthBloc(
          resolveStartup: sl(),
          signIn: sl(),
          registerNewUser: sl(),
          checkIntroCompleted: sl(),
          markIntroCompleted: sl(),
          postLoginActions: sl(),
        ),
        child: MaterialApp.router(
          routerConfig: router.config(),
        ),
      ),
    );
    // Skip auth bootstrap / Firebase-dependent initial routing.
    await router.replaceAll([const WelcomeRoute()]);
    await tester.pumpAndSettle();

    // Бачимо бренд
    expect(find.text('FLAP'), findsOneWidget);
    // Кнопки
    expect(find.text('УВІЙТИ'), findsOneWidget);
    expect(find.text('РЕЄСТРАЦІЯ'), findsOneWidget);

    // Переходимо на логін
    await tester.tap(find.text('УВІЙТИ'));
    await tester.pumpAndSettle();

    // Очікуємо елементи логіну
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}