import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cropcare_ai/app_state.dart';
import 'package:cropcare_ai/screens/auth_screen.dart';

void main() {
  testWidgets('Registration exposes the name field and validates empty input', (
    tester,
  ) async {
    final state = AppState();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
    final registerLink = find.text('New here? Create an account');
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    final submit = find.text('Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
