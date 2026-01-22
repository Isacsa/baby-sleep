import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Baby Profile Page - Edit baby name and date of birth
///
/// Minimal profile editor for Insights prerequisites:
/// - Name: optional (defaults to existing name if empty)
/// - Date of birth: required for age-based insights
///
/// On save:
/// - Updates local SQLite (marks for re-sync)
/// - Triggers auto-sync to push to Supabase
/// - Updates activeBaby and refreshes providers
class BabyProfilePage extends ConsumerStatefulWidget {
  final Baby baby;
  final bool showSkipOption;

  const BabyProfilePage({
    super.key,
    required this.baby,
    this.showSkipOption = false,
  });

  @override
  ConsumerState<BabyProfilePage> createState() => _BabyProfilePageState();
}

class _BabyProfilePageState extends ConsumerState<BabyProfilePage> {
  late TextEditingController _nameController;
  DateTime? _selectedBirthDate;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.baby.name);
    _selectedBirthDate = widget.baby.birthDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final maxAge = DateTime(now.year - 3, now.month, now.day); // Max 3 years ago

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? now,
      firstDate: maxAge,
      lastDate: now,
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: NightTheme.accent,
              onPrimary: NightTheme.textPrimary,
              surface: NightTheme.surface,
              onSurface: NightTheme.textPrimary,
            ),
            dialogTheme: DialogThemeData(backgroundColor: NightTheme.backgroundBase),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _save() async {
    // Validate birth date
    if (_selectedBirthDate == null) {
      setState(() {
        _errorMessage = 'Por favor, seleciona a data de nascimento.';
      });
      return;
    }

    // Validate birth date not in future
    if (_selectedBirthDate!.isAfter(DateTime.now())) {
      setState(() {
        _errorMessage = 'A data de nascimento não pode ser no futuro.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Get name (use existing if empty)
      final name = _nameController.text.trim().isEmpty
          ? widget.baby.name
          : _nameController.text.trim();

      // Update baby in local database
      final updatedBaby = await ref.read(babiesNotifierProvider.notifier).updateBaby(
        babyId: widget.baby.id,
        name: name,
        birthDate: _selectedBirthDate,
      );

      // Update active baby
      await ref.read(activeBabyProvider.notifier).setBaby(updatedBaby);

      // Trigger auto-sync
      ref.read(syncProvider.notifier).scheduleSyncAfterLocalChange(widget.baby.id);

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao guardar: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NightTheme.backgroundBase,
      appBar: AppBar(
        backgroundColor: NightTheme.backgroundBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: NightTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Perfil do bebé',
          style: TextStyle(
            color: NightTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Informações do bebé',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A data de nascimento é usada para personalizar os insights por idade.',
                style: TextStyle(
                  fontSize: 14,
                  color: NightTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // Name field
              const Text(
                'Nome (opcional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: NightTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ex: Maria, João...',
                  hintStyle: TextStyle(color: NightTheme.textSecondary.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: NightTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 24),

              // Birth date field
              const Text(
                'Data de nascimento',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectBirthDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: NightTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: _selectedBirthDate == null && _errorMessage != null
                        ? Border.all(color: NightTheme.warning, width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: NightTheme.accent,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedBirthDate != null
                            ? _formatDate(_selectedBirthDate!)
                            : 'Selecionar data',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedBirthDate != null
                              ? NightTheme.textPrimary
                              : NightTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: NightTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NightTheme.warning,
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NightTheme.accent,
                    foregroundColor: NightTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NightTheme.textPrimary,
                          ),
                        )
                      : const Text(
                          'Guardar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Skip option (if enabled)
              if (widget.showSkipOption) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Agora não',
                      style: TextStyle(
                        fontSize: 14,
                        color: NightTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Info note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NightTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: NightTheme.textSecondary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A idade é calculada automaticamente a partir da data de nascimento e usada para mostrar expectativas de sono apropriadas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: NightTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
