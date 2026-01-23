import 'package:flutter/material.dart';

/// A quick guide with short steps for the Relax tab.
@immutable
class RelaxGuide {
  final String id;
  final String title;
  final List<String> shortSteps;
  final String safetyNote;
  final int estimatedSeconds;

  const RelaxGuide({
    required this.id,
    required this.title,
    required this.shortSteps,
    required this.safetyNote,
    required this.estimatedSeconds,
  });

  factory RelaxGuide.fromJson(Map<String, dynamic> json) {
    return RelaxGuide(
      id: json['id'] as String,
      title: json['title'] as String,
      shortSteps: (json['shortSteps'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      safetyNote: json['safetyNote'] as String,
      estimatedSeconds: json['estimatedSeconds'] as int? ?? 60,
    );
  }
}

/// Night mode content (bullets for low-stimulation guidance).
@immutable
class NightModeContent {
  final List<String> bullets;

  const NightModeContent({required this.bullets});

  factory NightModeContent.fromJson(Map<String, dynamic> json) {
    return NightModeContent(
      bullets: (json['bullets'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}

/// Safe sleep checklist content.
@immutable
class SafetyChecklist {
  final String title;
  final List<String> items;
  final String warning;
  final String sources;

  const SafetyChecklist({
    required this.title,
    required this.items,
    required this.warning,
    required this.sources,
  });

  factory SafetyChecklist.fromJson(Map<String, dynamic> json) {
    return SafetyChecklist(
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      warning: json['warning'] as String,
      sources: json['sources'] as String,
    );
  }
}

/// Complete relax content for a locale.
@immutable
class RelaxContent {
  final List<RelaxGuide> guides;
  final NightModeContent nightMode;
  final SafetyChecklist safetyChecklist;
  final String volumeSafetyMessage;
  final String volumeHighWarning;
  final String disclaimer;

  const RelaxContent({
    required this.guides,
    required this.nightMode,
    required this.safetyChecklist,
    required this.volumeSafetyMessage,
    required this.volumeHighWarning,
    required this.disclaimer,
  });

  factory RelaxContent.fromJson(Map<String, dynamic> json) {
    return RelaxContent(
      guides: (json['guides'] as List<dynamic>)
          .map((e) => RelaxGuide.fromJson(e as Map<String, dynamic>))
          .toList(),
      nightMode: NightModeContent.fromJson(json['nightMode'] as Map<String, dynamic>),
      safetyChecklist: SafetyChecklist.fromJson(json['safetyChecklist'] as Map<String, dynamic>),
      volumeSafetyMessage: json['volumeSafetyMessage'] as String,
      volumeHighWarning: json['volumeHighWarning'] as String,
      disclaimer: json['disclaimer'] as String,
    );
  }
}
