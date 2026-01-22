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
const supportedLocales = [
  Locale('en'), // English (default)
  Locale('pt'), // Portuguese
];
