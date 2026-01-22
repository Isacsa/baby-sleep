import 'package:flutter/widgets.dart';
import 'package:temp_flutter/l10n/generated/app_localizations.dart';

export 'package:temp_flutter/l10n/generated/app_localizations.dart';

/// Extension to easily access AppLocalizations from BuildContext.
///
/// Usage:
/// ```dart
/// Text(context.l10n.homeGreeting)
/// ```
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// Supported locales for the app.
/// 
/// Order matters: first locale is the fallback if no match is found.
const supportedLocales = [
  Locale('en'), // English (default/fallback)
  Locale('pt'), // Portuguese
];

/// Centralized locale resolution policy.
/// 
/// Rules (in order of priority):
/// 1. If device language is Portuguese (any variant) → pt
/// 2. If device region/country is Portugal (PT) → pt
/// 3. Otherwise → en (fallback)
/// 
/// This ensures users in Portugal or with Portuguese language settings
/// always see Portuguese, while everyone else sees English.
/// 
/// Prepared for future expansion (e.g., pt_BR, es, fr) by checking
/// both languageCode and countryCode.
class AppLocalePolicy {
  /// Resolves the app locale based on device locale settings.
  /// 
  /// [deviceLocale] - The primary locale from the device.
  /// [deviceLocales] - The full list of preferred locales (iOS/Android).
  /// [supportedLocales] - The locales our app supports.
  /// 
  /// Returns the best matching supported locale.
  static Locale resolve(
    Locale? deviceLocale,
    Iterable<Locale>? deviceLocales,
    Iterable<Locale> supported,
  ) {
    // If no device locale, fall back to English
    if (deviceLocale == null) {
      return const Locale('en');
    }

    // Check all preferred locales (iOS can have a list)
    final localesToCheck = deviceLocales ?? [deviceLocale];
    
    for (final locale in localesToCheck) {
      // Rule 1: Portuguese language (pt, pt_PT, pt_BR, etc.) → Portuguese
      if (locale.languageCode == 'pt') {
        return const Locale('pt');
      }
      
      // Rule 2: Region is Portugal → Portuguese (even if language is EN)
      if (locale.countryCode == 'PT') {
        return const Locale('pt');
      }
    }

    // Rule 3: Default to English
    return const Locale('en');
  }
}
