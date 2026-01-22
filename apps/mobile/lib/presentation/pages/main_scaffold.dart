import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/auth_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/presentation/widgets/starry_background.dart';
import 'package:temp_flutter/presentation/widgets/floating_bottom_bar.dart';
import 'package:temp_flutter/presentation/pages/home_sleep_page.dart';
import 'package:temp_flutter/presentation/pages/insights_page.dart';
import 'package:temp_flutter/presentation/pages/relax_page.dart';
import 'package:temp_flutter/presentation/pages/stats_page.dart';

/// MainScaffold - Container principal com navegação por tabs
/// 
/// Estrutura:
/// - StarryBackground como fundo
/// - IndexedStack para manter estado das tabs
/// - FloatingBottomBar para navegação
/// 
/// AUTO-PULL:
/// - Integra WidgetsBindingObserver para detetar foreground/background
/// - Inicia polling automático quando há baby ativo
/// - Para polling quando app vai para background
/// - Reinicia polling + pull imediato quando app volta ao foreground
/// 
/// Tabs:
/// 0. Sono (Home)
/// 1. Relaxar
/// 2. Estatísticas
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  
  /// Subscription for baby changes - MUST be closed in dispose()
  /// FIX: Prevents "Cannot use ref after disposed" crash
  ProviderSubscription<Baby?>? _activeBabySubscription;

  final List<Widget> _pages = const [
    HomeSleepPage(),
    InsightsPage(),
    RelaxPage(),
    StatsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Registar observer para detetar lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Iniciar auto-pull após o primeiro frame (quando providers estão prontos)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAutoPullIfNeeded();
      }
    });
  }
  
  @override
  void dispose() {
    // FIX: Close the subscription to prevent "Cannot use ref after disposed"
    _activeBabySubscription?.close();
    _activeBabySubscription = null;
    
    // Remover observer
    WidgetsBinding.instance.removeObserver(this);
    // Parar auto-pull
    ref.read(syncProvider.notifier).stopAutoPull();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // FIX: Guard against using ref after disposed
    if (!mounted) return;
    
    final syncNotifier = ref.read(syncProvider.notifier);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao foreground → pull imediato + reiniciar timer
        // ignore: avoid_print
        print('[MainScaffold] App RESUMED');
        syncNotifier.onAppResumed();
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App vai para background → parar timer
        // ignore: avoid_print
        print('[MainScaffold] App PAUSED/INACTIVE');
        syncNotifier.onAppPaused();
    }
  }
  
  /// Inicia auto-pull se houver user autenticado e baby ativo
  void _startAutoPullIfNeeded() {
    if (!mounted) return;
    
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    // Guardrails: não iniciar se não há user ou baby
    if (user == null) {
      // ignore: avoid_print
      print('[MainScaffold] Auto-pull NOT started: user is null');
      return;
    }
    
    if (activeBaby == null) {
      // ignore: avoid_print
      print('[MainScaffold] Auto-pull NOT started: activeBaby is null');
      return;
    }
    
    // Iniciar auto-pull
    ref.read(syncProvider.notifier).startAutoPull(babyId: activeBaby.id);
    
    // FIX: Store the subscription so we can close it in dispose()
    // This prevents "Cannot use ref after disposed" crash
    _activeBabySubscription = ref.listenManual<Baby?>(activeBabyProvider, (previous, next) {
      // FIX: Guard against callback firing after dispose
      if (!mounted) return;
      
      if (next == null) {
        // Baby desativado → parar polling
        ref.read(syncProvider.notifier).stopAutoPull();
      } else if (previous?.id != next.id) {
        // Baby mudou → reiniciar polling para novo baby
        ref.read(syncProvider.notifier).startAutoPull(babyId: next.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: FloatingBottomBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          items: [
            FloatingBottomBarItem(
              icon: Icons.bedtime_outlined,
              selectedIcon: Icons.bedtime,
              label: context.l10n.tabSleep,
            ),
            FloatingBottomBarItem(
              icon: Icons.lightbulb_outline,
              selectedIcon: Icons.lightbulb,
              label: context.l10n.tabInsights,
            ),
            FloatingBottomBarItem(
              icon: Icons.spa_outlined,
              selectedIcon: Icons.spa,
              label: context.l10n.tabRelax,
            ),
            FloatingBottomBarItem(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              label: context.l10n.tabStats,
            ),
          ],
        ),
      ),
    );
  }
}
