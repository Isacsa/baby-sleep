import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/guide_provider.dart';
import 'package:temp_flutter/domain/content/content.dart';
import 'package:temp_flutter/l10n/generated/app_localizations.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Guide Detail Page v2 - Uses asset-based content with l10n
///
/// Loads content from Markdown assets with locale fallback.
class GuideDetailPageV2 extends ConsumerWidget {
  final String sectionId;

  const GuideDetailPageV2({
    super.key,
    required this.sectionId,
  });

  /// Navigate to a guide section by ID
  static void navigateTo(BuildContext context, String sectionId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GuideDetailPageV2(sectionId: sectionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final sectionAsync = ref.watch(guideSectionProvider((sectionId, locale)));

    return Scaffold(
      backgroundColor: NightTheme.backgroundBase,
      appBar: AppBar(
        backgroundColor: NightTheme.backgroundBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NightTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _getLocalizedTitle(l10n, sectionId),
          style: const TextStyle(
            color: NightTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: sectionAsync.when(
        data: (section) => _buildContent(context, l10n, section),
        loading: () => const Center(
          child: CircularProgressIndicator(color: NightTheme.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: NightTheme.warning),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível carregar o conteúdo.',
                  style: const TextStyle(color: NightTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, GuideSection section) {
    final sourceIds = section.meta.sourceIds;
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NightTheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIcon(section.meta.icon),
                    size: 28,
                    color: NightTheme.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLocalizedTitle(l10n, sectionId),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: NightTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getLocalizedSubtitle(l10n, sectionId),
                        style: const TextStyle(
                          fontSize: 14,
                          color: NightTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Content from Markdown
            _buildFormattedContent(section.content),

            const SizedBox(height: 28),

            // Sources
            if (sourceIds.isNotEmpty) ...[
              Text(
                l10n.insightsSourcesTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final sourcesAsync = ref.watch(sourcesByIdsProvider(sourceIds));
                  return sourcesAsync.when(
                    data: (sources) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sources
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: NightTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: NightTheme.textSecondary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NightTheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: NightTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.guideDisclaimer,
                      style: const TextStyle(
                        fontSize: 11,
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
    );
  }

  String _getLocalizedTitle(AppLocalizations l10n, String sectionId) {
    switch (sectionId) {
      case GuideSectionId.normalPorIdade:
        return l10n.guide_normal_por_idade_title;
      case GuideSectionId.diaVsNoite:
        return l10n.guide_dia_vs_noite_title;
      case GuideSectionId.rotinaAntesDormir:
        return l10n.guide_rotina_antes_dormir_title;
      case GuideSectionId.sonoSeguro:
        return l10n.guide_sono_seguro_title;
      case GuideSectionId.quandoPediatra:
        return l10n.guide_quando_pediatra_title;
      default:
        return sectionId;
    }
  }

  String _getLocalizedSubtitle(AppLocalizations l10n, String sectionId) {
    switch (sectionId) {
      case GuideSectionId.normalPorIdade:
        return l10n.guide_normal_por_idade_subtitle;
      case GuideSectionId.diaVsNoite:
        return l10n.guide_dia_vs_noite_subtitle;
      case GuideSectionId.rotinaAntesDormir:
        return l10n.guide_rotina_antes_dormir_subtitle;
      case GuideSectionId.sonoSeguro:
        return l10n.guide_sono_seguro_subtitle;
      case GuideSectionId.quandoPediatra:
        return l10n.guide_quando_pediatra_subtitle;
      default:
        return '';
    }
  }

  Widget _buildFormattedContent(String content) {
    // Simple markdown-like parser
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      if (line.startsWith('**') && line.endsWith('**')) {
        // Bold header
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.replaceAll('**', ''),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: NightTheme.textPrimary,
            ),
          ),
        ));
      } else if (line.startsWith('• ') || line.startsWith('☐ ')) {
        // Bullet point or checkbox
        final isCheckbox = line.startsWith('☐ ');
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCheckbox)
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: NightTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              else
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: const BoxDecoration(
                    color: NightTheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: _buildInlineFormattedText(
                  isCheckbox ? line.substring(2) : line.substring(2),
                ),
              ),
            ],
          ),
        ));
      } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        // Numbered list
        final match = RegExp(r'^(\d+)\. (.*)').firstMatch(line);
        if (match != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${match.group(1)}.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NightTheme.secondary,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildInlineFormattedText(match.group(2) ?? ''),
                ),
              ],
            ),
          ));
        }
      } else {
        // Regular paragraph
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildInlineFormattedText(line),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildInlineFormattedText(String text) {
    // Handle inline bold (**text**)
    final parts = <InlineSpan>[];
    final regex = RegExp(r'\*\*([^*]+)\*\*');
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        parts.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(fontSize: 14, color: NightTheme.textBody, height: 1.5),
        ));
      }
      parts.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: NightTheme.textPrimary,
          height: 1.5,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      parts.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(fontSize: 14, color: NightTheme.textBody, height: 1.5),
      ));
    }

    if (parts.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14, color: NightTheme.textBody, height: 1.5),
      );
    }

    return RichText(
      text: TextSpan(children: parts),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'child_care':
        return Icons.child_care;
      case 'brightness_4':
        return Icons.brightness_4;
      case 'format_list_numbered':
        return Icons.format_list_numbered;
      case 'verified_user':
        return Icons.verified_user;
      case 'medical_services_outlined':
        return Icons.medical_services_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
