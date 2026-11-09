import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'config/telegram_config.dart';
import 'screens/auth.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(BlastApp(state: state));
}

/// BA BLAST GRAM — a premium Telegram client in Flutter & Dart.
///
/// Real Telegram only. The owner's api_id/api_hash are stored encrypted
/// in the native library; end users log in with phone + OTP.
class BlastApp extends StatelessWidget {
  const BlastApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: TelegramConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: appState.themeMode,
            home: const SplashGate(),
          );
        },
      ),
    );
  }
}

/// Shows the animated splash briefly, then the auth-aware root screen.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const SplashScreen();
    return const RootScreen();
  }
}

/// Picks the screen from the login state — no nested navigation tricks:
/// the whole root swaps when [AppState.authStep] changes.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool _showPhone = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.initialized) return const SplashScreen();
    switch (state.authStep) {
      case AuthStep.loggedIn:
        return const HomeScreen();
      case AuthStep.awaitingCode:
        return const LoginOtpScreen();
      case AuthStep.awaitingPassword:
        return const LoginTwoFaScreen();
      case AuthStep.loggedOut:
        if (_showPhone) {
          return LoginPhoneScreen(onBack: () {
            setState(() => _showPhone = false);
          });
        }
        return OnboardingScreen(
          onStart: () => setState(() => _showPhone = true),
        );
    }
  }
}
