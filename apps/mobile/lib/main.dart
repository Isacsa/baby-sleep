import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client_impl.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/pages/auth_gate.dart';
import 'package:temp_flutter/presentation/pages/login_page.dart';
import 'package:temp_flutter/presentation/pages/babies_page.dart';
import 'package:temp_flutter/presentation/pages/main_scaffold.dart';
import 'package:temp_flutter/presentation/pages/day_detail_page.dart';
import 'package:temp_flutter/presentation/pages/timeline_page.dart';
import 'package:temp_flutter/presentation/pages/debug_page.dart';

/// App entry point
/// 
/// Initialization order (critical):
/// 1. Flutter bindings (WidgetsFlutterBinding.ensureInitialized)
/// 2. Load .env file (via SupabaseConfig.initialize)
/// 3. Initialize Supabase SDK (via SupabaseClientImpl.initialize)
/// 4. Run app with ProviderScope
void main() async {
  // Step 1: Ensure Flutter bindings are initialized
  // Required for async operations before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Step 2 & 3: Initialize Supabase (loads .env and initializes SDK)
  // This must happen before any provider tries to use Supabase.instance
  await SupabaseClientImpl.initialize();

  // Step 4: Run app - now Supabase is ready
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Sleep',
      debugShowCheckedModeBanner: false,
      
      // Localization configuration
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      
      // Night Theme - conforme spec
      theme: NightTheme.themeData,
      darkTheme: NightTheme.themeData,
      themeMode: ThemeMode.dark,
      
      // AuthGate is the entry point - decides where to navigate
      home: const AuthGate(),
      
      routes: {
        '/login': (context) => const LoginPage(),
        '/babies': (context) => const BabiesPage(),
        '/home': (context) => const MainScaffold(),
        '/day-detail': (context) => const DayDetailPage(),
        '/timeline': (context) => const TimelinePage(),
        // Debug route only in debug mode
        if (kDebugMode) '/debug': (context) => const DebugPage(),
      },
      
      onGenerateRoute: (settings) {
        // Handle debug route access in release mode
        if (settings.name == '/debug' && !kDebugMode) {
          return MaterialPageRoute(
            builder: (context) => const AuthGate(),
          );
        }
        // Redirect old /baby route to new /home
        if (settings.name == '/baby') {
          return MaterialPageRoute(
            builder: (context) => const MainScaffold(),
          );
        }
        return null;
      },
    );
  }
}
