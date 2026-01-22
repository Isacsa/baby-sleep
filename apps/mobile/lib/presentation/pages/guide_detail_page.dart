import 'package:flutter/material.dart';
import 'package:temp_flutter/domain/guide/guide_content.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Guide Detail Page - Shows full guide content
///
/// Displays curated educational content with sources.
class GuideDetailPage extends StatelessWidget {
  final GuideContent content;

  const GuideDetailPage({
    super.key,
    required this.content,
  });

  /// Navigate to a guide section by ID
  static void navigateTo(BuildContext context, String guideId) {
    final content = GuideContentRepository.getById(guideId);
    if (content != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GuideDetailPage(content: content),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          content.title,
          style: const TextStyle(
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
                      _getIcon(content.iconName),
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
                          content.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: NightTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content.subtitle,
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

              // Content
              _buildFormattedContent(content.content),

              const SizedBox(height: 28),

              // Sources
              if (content.sources.isNotEmpty) ...[
                const Text(
                  'Fontes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NightTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: content.sources
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
                const SizedBox(height: 24),
              ],

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NightTheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: NightTheme.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Informação educativa; não substitui aconselhamento médico.',
                        style: TextStyle(
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
      ),
    );
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
                  decoration: BoxDecoration(
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
