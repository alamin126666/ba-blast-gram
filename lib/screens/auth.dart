import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/avatars.dart';

/// Splash, onboarding and the phone → OTP → 2FA login flow.
///
/// Login is real Telegram only: the owner's api_id/api_hash must be
/// stored encrypted in the native library (see TelegramConfig).
/// If they are missing,
/// the phone screen explains that instead of pretending to work.

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BlastColors.brandGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  BlastLogo(size: 110, showName: false),
                  SizedBox(height: 22),
                  Text(
                    'BA BLAST GRAM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fast. Secure. Blast it.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 36),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<(IconData, String, String)> _pages = <(IconData, String, String)>[
    (
      Icons.bolt_rounded,
      'Blast fast',
      'Messages fly on Telegram\'s worldwide network — fast, reliable, and free.',
    ),
    (
      Icons.lock_rounded,
      'Private & secure',
      'Your chats stay yours. Log in with your own phone number and OTP, just like Telegram.',
    ),
    (
      Icons.auto_awesome_rounded,
      'Everything Telegram has',
      'Chats, groups, channels, stories, saved messages and more — in a premium BA BLAST GRAM skin.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final (icon, title, subtitle) = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: BlastColors.brandGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 56),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _page == i ? 26 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _page == i
                        ? BlastColors.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _page == _pages.length - 1
                      ? widget.onStart
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          ),
                  child: Text(
                    _page == _pages.length - 1 ? 'Start Messaging' : 'Next',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Powered by the Telegram API • BA BLAST GRAM',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final configured = state.apiConfigured;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Your phone number'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Enter your Telegram phone number. We will send you an OTP code to confirm it.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              enabled: configured && !state.authBusy,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+880 1XXX-XXXXXX',
                prefixIcon: Icon(Icons.phone_android),
              ),
              onSubmitted: (_) => _submit(state),
            ),
            const SizedBox(height: 16),
            if (!configured)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'API keys not configured — owner must add api_id/api_hash. '
                  'This build does not have the owner\'s Telegram API '
                  'credentials yet. They live encrypted in the native '
                  'library — the owner adds them once and rebuilds. '
                  'Then you just log in with phone + OTP — no keys needed.',
                  style: TextStyle(fontSize: 13.5, height: 1.5),
                ),
              ),
            if (state.authError != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  state.authError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13.5),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: !configured || state.authBusy
                    ? null
                    : () => _submit(state),
                child: state.authBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'By continuing you agree that BA BLAST GRAM connects to '
              'Telegram with the official Telegram API.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(AppState state) {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number.')),
      );
      return;
    }
    state.sendCode(phone);
  }
}

class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({super.key});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Enter code')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Telegram sent an OTP code to ${state.phoneNumber}. Enter it below.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 5,
              textAlign: TextAlign.center,
              enabled: !state.authBusy,
              style: const TextStyle(fontSize: 26, letterSpacing: 10),
              decoration: const InputDecoration(
                hintText: '• • • • •',
                counterText: '',
              ),
              onSubmitted: (_) => _submit(state),
            ),
            if (state.authError != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  state.authError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13.5),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: state.authBusy ? null : () => _submit(state),
                child: state.authBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Verify', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.authBusy
                  ? null
                  : () => state.sendCode(state.phoneNumber),
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(AppState state) {
    final code = _codeController.text.trim();
    if (code.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 5-digit code.')),
      );
      return;
    }
    state.submitCode(code);
  }
}

class LoginTwoFaScreen extends StatefulWidget {
  const LoginTwoFaScreen({super.key});

  @override
  State<LoginTwoFaScreen> createState() => _LoginTwoFaScreenState();
}

class _LoginTwoFaScreenState extends State<LoginTwoFaScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Two-step verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Your account has two-step verification. Enter your cloud password.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              enabled: !state.authBusy,
              decoration: InputDecoration(
                labelText: '2FA password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(state),
            ),
            if (state.authError != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  state.authError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13.5),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: state.authBusy ? null : () => _submit(state),
                child: state.authBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: if you forgot this password, recover it from the '
              'official Telegram app — it cannot be reset from here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(AppState state) {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your 2FA password.')),
      );
      return;
    }
    state.submitPassword(password);
  }
}
