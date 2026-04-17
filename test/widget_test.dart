import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flap_app/router/app_router.dart';
import 'package:flap_app/screens/login_screen.dart';
import 'package:flap_app/utils/i18n.dart';

void main() {
  testWidgets('Welcome screen renders and navigates to Login', (WidgetTester tester) async {
    I18n.setLanguage('uk');
    final router = AppRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
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