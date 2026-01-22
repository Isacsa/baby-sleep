import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for customizable bedtime routine checklists
///
/// Stores per-baby routine checklists that users can personalize.
class RoutineChecklistLocalDataSource {
  static const String _prefix = 'routine_checklist_';

  /// Default routine steps (Portuguese)
  static const List<String> defaultSteps = [
    'Banho ou limpeza',
    'Vestir pijama',
    'Canção ou história curta',
    'Luz baixa e despedida',
  ];

  /// Gets the routine checklist for a baby
  /// 
  /// Returns the custom checklist if saved, otherwise returns defaults.
  Future<List<String>> getChecklist(String babyId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _checklistKey(babyId);
    final json = prefs.getString(key);
    
    if (json == null) return List.from(defaultSteps);
    
    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.cast<String>();
    } catch (e) {
      return List.from(defaultSteps);
    }
  }

  /// Saves a custom routine checklist for a baby
  Future<void> saveChecklist(String babyId, List<String> steps) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _checklistKey(babyId);
    await prefs.setString(key, jsonEncode(steps));
  }

  /// Resets the checklist to defaults
  Future<void> resetToDefaults(String babyId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _checklistKey(babyId);
    await prefs.remove(key);
  }

  /// Adds a step to the checklist
  Future<List<String>> addStep(String babyId, String step) async {
    final current = await getChecklist(babyId);
    current.add(step);
    await saveChecklist(babyId, current);
    return current;
  }

  /// Removes a step from the checklist
  Future<List<String>> removeStep(String babyId, int index) async {
    final current = await getChecklist(babyId);
    if (index >= 0 && index < current.length) {
      current.removeAt(index);
      await saveChecklist(babyId, current);
    }
    return current;
  }

  /// Reorders a step in the checklist
  Future<List<String>> reorderStep(String babyId, int oldIndex, int newIndex) async {
    final current = await getChecklist(babyId);
    if (oldIndex >= 0 && oldIndex < current.length &&
        newIndex >= 0 && newIndex < current.length) {
      final step = current.removeAt(oldIndex);
      current.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, step);
      await saveChecklist(babyId, current);
    }
    return current;
  }

  /// Updates a step text
  Future<List<String>> updateStep(String babyId, int index, String newText) async {
    final current = await getChecklist(babyId);
    if (index >= 0 && index < current.length) {
      current[index] = newText;
      await saveChecklist(babyId, current);
    }
    return current;
  }

  String _checklistKey(String babyId) => '$_prefix$babyId';
}
