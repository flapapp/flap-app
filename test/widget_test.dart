import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flap_app/core/di/injection.dart';
import 'package:flap_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flap_app/features/auth/presentation/pages/login_page.dart';
import 'package:flap_app/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await sl.reset();
    await configureDependencies();
  });

  testWidgets('Welcome and Login screens (easy_localization smoke)', (tester) async {
    Future<void> pumpL10nApp(Widget app) async {
      await tester.pumpWidget(app);
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pumpAndSettle();
    }

    await pumpL10nApp(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('uk')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        startLocale: const Locale('uk'),
        saveLocale: false,
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: const [Locale('en'), Locale('uk')],
              locale: const Locale('uk'),
              home: const WelcomeScreen(),
            );
          },
        ),
      ),
    );

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('FLAP'), findsOneWidget);
    expect(find.text('УВІЙТИ'), findsOneWidget);
    expect(find.text('РЕЄСТРАЦІЯ'), findsOneWidget);

    await pumpL10nApp(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('uk')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        startLocale: const Locale('uk'),
        saveLocale: false,
        child: Builder(
          builder: (context) {
            return BlocProvider<AuthBloc>(
              create: (_) => AuthBloc(
                resolveStartup: sl(),
                signIn: sl(),
                registerNewUser: sl(),
                checkIntroCompleted: sl(),
                markIntroCompleted: sl(),
                postLoginActions: sl(),
              ),
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: const [Locale('en'), Locale('uk')],
                locale: const Locale('uk'),
                home: const LoginScreen(),
              ),
            );
          },
        ),
      ),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
