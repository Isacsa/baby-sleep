import 'package:flutter/material.dart';

/// Night Theme - Baby Sleep MVP
/// 
/// Paleta baseada em tons escuros para uso noturno,
/// conforme especificação em docs/ui/ui_spec.md
class NightTheme {
  NightTheme._();

  // === CORES DA SPEC ===
  
  /// Fundo Topo - Início do gradiente (Slate 900)
  static const Color backgroundTop = Color(0xFF0F172A);
  
  /// Fundo Base - Fim do gradiente (Slate 800)
  static const Color backgroundBase = Color(0xFF1E293B);
  
  /// Primária - Botão Start, ícone sono ativo (Sky 400)
  static const Color primary = Color(0xFF38BDF8);
  
  /// Secundária - Botão End, destaques (Indigo 400)
  static const Color secondary = Color(0xFF818CF8);
  
  /// Acento (Estrelas) - Estrelas subtis, alertas suaves (Yellow 300)
  static const Color accent = Color(0xFFFDE047);
  
  /// Superfície - Cards e Bottom Sheets (com 80% opacidade)
  static const Color surface = Color(0xCC1E293B);
  
  /// Texto Principal - Títulos e corpo (Slate 50)
  static const Color textPrimary = Color(0xFFF8FAFC);
  
  /// Texto Secundário - Notas, labels, microcopy (Slate 400)
  static const Color textSecondary = Color(0xFF94A3B8);
  
  /// Erro/Alerta - Erros de sincronização (Rose 400)
  static const Color error = Color(0xFFFB7185);
  
  /// Slate 200 - Body text
  static const Color textBody = Color(0xFFE2E8F0);

  // === GRADIENTE DE FUNDO ===
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBase],
  );

  // === THEME DATA ===
  
  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: backgroundBase,
      error: error,
      onPrimary: backgroundTop,
      onSecondary: backgroundTop,
      onSurface: textPrimary,
      onError: backgroundTop,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: Colors.transparent,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    
    // Typography
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      // H1 - Título Home
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      // H2 - Títulos Secção
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      // Title
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textBody,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textBody,
      ),
      // Caption/Small
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
    ),
    
    // Cards
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: backgroundTop,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
      ),
    ),
    
    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: primary.withValues(alpha: 0.2),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      side: BorderSide.none,
    ),
    
    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    
    // Dialogs
    dialogTheme: DialogThemeData(
      backgroundColor: backgroundBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    
    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: backgroundBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    
    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
    
    // Divider
    dividerTheme: DividerThemeData(
      color: textSecondary.withValues(alpha: 0.2),
      thickness: 1,
    ),
    
    // Progress Indicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primary,
    ),
  );
}
