import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blastgram/main.dart';
import 'package:blastgram/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> buildState() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AppState();
    await state.init();
    return state;
  }

  testWidgets('App boots to the BA BLAST GRAM splash, then onboarding',
      (tester) async {
    final state = await buildState();
    await tester.pumpWidget(BlastApp(state: state));
    await tester.pump();

    // Splash shows the brand.
    expect(find.text('BA BLAST GRAM'), findsOneWidget);

    // After the splash delay, onboarding appears.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Blast fast'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Login flow shows API-not-configured state without keys',
      (tester) async {
    final state = await buildState();
    await tester.pumpWidget(BlastApp(state: state));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    // Walk through the three onboarding pages.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Messaging'));
    await tester.pumpAndSettle();

    // Phone screen appears and honestly reports the missing credentials.
    expect(find.text('Your phone number'), findsOneWidget);
    expect(find.textContaining('does not have'), findsOneWidget);
    // Continue is disabled without compiled-in API keys.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('AppState starts logged out with no service without keys',
      (tester) async {
    final state = await buildState();
    expect(state.initialized, isTrue);
    expect(state.isLoggedIn, isFalse);
    expect(state.apiConfigured, isFalse);
    expect(state.authStep, AuthStep.loggedOut);
    expect(state.chats, isEmpty);
  });
}
