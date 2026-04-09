import 'package:flap_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flap_app/utils/i18n.dart';

void main() {
  testWidgets('Welcome screen renders primary actions', (WidgetTester tester) async {
    I18n.setLanguage('uk');
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('FLAP'), findsOneWidget);
    expect(find.text('УВІЙТИ'), findsOneWidget);
    expect(find.text('РЕЄСТРАЦІЯ'), findsOneWidget);
  });
}