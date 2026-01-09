import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client_impl.dart';
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
      title: 'Baby Sleep Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DebugPage(),
    );
  }
}
