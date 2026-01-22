import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/auth_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/presentation/widgets/starry_background.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// LoginPage - Simple magic link authentication
/// 
/// Minimal MVP implementation:
/// - Email input
/// - Send Magic Link button
/// - Status messages
/// 
/// After successful auth (via email link), authProvider updates
/// and AuthGate handles navigation automatically.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _linkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);

    // If user becomes authenticated, navigate via AuthGate
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
    }

    return StarryScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Header
                const Icon(
                  Icons.bedtime_rounded,
                  size: 80,
                  color: NightTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.appTitle,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: NightTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.loginTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: NightTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email input
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: context.l10n.loginEmail,
                    hintText: 'your@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_isLoading && !_linkSent,
                ),
                const SizedBox(height: 16),

                // Send button
                FilledButton(
                  onPressed: _isLoading || _linkSent ? null : _sendMagicLink,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.l10n.loginButton),
                ),
                const SizedBox(height: 24),

                // Status message
                if (_message != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _linkSent
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _linkSent ? Icons.check_circle : Icons.error_outline,
                          color: _linkSent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _linkSent
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Retry link
                if (_linkSent) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _linkSent = false;
                        _message = null;
                      });
                    },
                    child: const Text('Use a different email'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _message = 'Please enter a valid email address';
        _linkSent = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await ref.read(authProvider.notifier).sendMagicLink(email);
      setState(() {
        _isLoading = false;
        _linkSent = true;
        _message = 'Magic link sent! Check your email and tap the link to sign in.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _linkSent = false;
        _message = 'Failed to send magic link. Please try again.';
      });
    }
  }
}
