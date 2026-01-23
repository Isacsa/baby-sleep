import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to request tab navigation from child widgets.
/// MainScaffold listens to this and updates the current tab.
final requestedTabIndexProvider = StateProvider<int?>((ref) => null);

/// Tab indices for the main navigation.
class MainTabs {
  static const int sleep = 0;
  static const int insights = 1;
  static const int relax = 2;
  static const int stats = 3;
}
