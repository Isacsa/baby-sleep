import 'dart:math';
import 'package:flutter/material.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// StarryBackground - Fundo gradiente com estrelas fixas
/// 
/// Componente visual decorativo conforme spec:
/// - Gradiente #0F172A → #1E293B
/// - Estrelas fixas com opacidade variável (0.1 a 0.3)
/// - Não animado para performance
class StarryBackground extends StatelessWidget {
  final Widget child;
  
  const StarryBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradiente de fundo
        Container(
          decoration: const BoxDecoration(
            gradient: NightTheme.backgroundGradient,
          ),
        ),
        // Estrelas
        CustomPaint(
          painter: _StarryPainter(),
          size: Size.infinite,
        ),
        // Conteúdo
        child,
      ],
    );
  }
}

/// CustomPainter para desenhar estrelas
class _StarryPainter extends CustomPainter {
  // Seed fixo para posições consistentes
  static const int _starCount = 50;
  
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Seed fixo para consistência
    
    for (int i = 0; i < _starCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.5 + random.nextDouble() * 1.5; // 0.5 a 2.0
      final opacity = 0.1 + random.nextDouble() * 0.2; // 0.1 a 0.3
      
      final paint = Paint()
        ..color = NightTheme.accent.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// StarryScaffold - Scaffold com StarryBackground integrado
/// 
/// Conveniência para páginas que usam o fundo estrelado
class StarryScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final bool extendBody;

  const StarryScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
    this.extendBody = true,
  });

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        extendBody: extendBody,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
