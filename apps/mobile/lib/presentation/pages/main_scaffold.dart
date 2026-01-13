import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/presentation/widgets/starry_background.dart';
import 'package:temp_flutter/presentation/widgets/floating_bottom_bar.dart';
import 'package:temp_flutter/presentation/pages/home_sleep_page.dart';
import 'package:temp_flutter/presentation/pages/relax_page.dart';
import 'package:temp_flutter/presentation/pages/stats_page.dart';

/// MainScaffold - Container principal com navegação por tabs
/// 
/// Estrutura:
/// - StarryBackground como fundo
/// - IndexedStack para manter estado das tabs
/// - FloatingBottomBar para navegação
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

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeSleepPage(),
    RelaxPage(),
    StatsPage(),
  ];

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
          items: const [
            FloatingBottomBarItem(
              icon: Icons.bedtime_outlined,
              selectedIcon: Icons.bedtime,
              label: 'Sono',
            ),
            FloatingBottomBarItem(
              icon: Icons.spa_outlined,
              selectedIcon: Icons.spa,
              label: 'Relaxar',
            ),
            FloatingBottomBarItem(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              label: 'Estatísticas',
            ),
          ],
        ),
      ),
    );
  }
}
