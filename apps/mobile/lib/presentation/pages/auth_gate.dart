import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/auth_provider.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';

/// AuthGate - Entry point that decides where to navigate based on auth state
/// 
/// Navigation logic:
/// 1. If not authenticated → LoginPage
/// 2. If authenticated but no active baby → BabiesPage
/// 3. If authenticated and active baby exists in cache → BabyHomePage
/// 
/// GUARDRAIL 1: If activeBabyId exists but baby not in SQLite cache,
/// we navigate to /babies instead of /baby to prevent accessing
/// a non-existent baby. This can happen on a new device where
/// SharedPreferences has the ID but SQLite is empty.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final activeBaby = ref.watch(activeBabyProvider);
    final babiesAsync = ref.watch(babiesNotifierProvider);

    // Show loading while checking initial state
    if (babiesAsync.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    // Navigate based on state (only once per state change)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasNavigated) return;

      if (user == null) {
        // Not authenticated → Login
        _navigateTo('/login');
      } else if (activeBaby == null) {
        // Authenticated but no active baby → Babies list
        _navigateTo('/babies');
      } else {
        // GUARDRAIL 1: Check if active baby exists in local cache
        final babies = babiesAsync.value ?? [];
        final existsInCache = babies.any((b) => b.id == activeBaby.id);

        if (existsInCache) {
          // Active baby exists locally → Go to baby home
          _navigateTo('/baby');
        } else {
          // Active baby ID exists but not in SQLite cache
          // This happens on new device with persisted SharedPreferences
          // Navigate to babies page to pull/select a valid baby
          // ignore: avoid_print
          print('[AuthGate] Active baby ${activeBaby.id} not in cache, '
              'navigating to /babies');
          _navigateTo('/babies');
        }
      }
    });

    // While deciding, show splash-like screen
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bedtime_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Baby Sleep',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  void _navigateTo(String route) {
    if (!mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacementNamed(route);
  }
}
