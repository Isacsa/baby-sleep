import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';

/// Loader for curated sleep expectations from bundled JSON assets
///
/// Implements a singleton pattern with in-memory cache to avoid
/// re-reading assets on every access.
class CuratedSleepExpectationsLoader {
  static CuratedSleepExpectationsLoader? _instance;
  static const String _assetPath = 'assets/curated/sleep_expectations_v1_pt.json';

  Map<SleepAgeBand, SleepExpectations>? _cache;
  int? _schemaVersion;
  String? _updatedAt;
  bool _isLoaded = false;

  CuratedSleepExpectationsLoader._();

  /// Gets the singleton instance
  static CuratedSleepExpectationsLoader get instance {
    _instance ??= CuratedSleepExpectationsLoader._();
    return _instance!;
  }

  /// Whether the data has been loaded
  bool get isLoaded => _isLoaded;

  /// The schema version from the JSON
  int? get schemaVersion => _schemaVersion;

  /// When the curated data was last updated
  String? get updatedAt => _updatedAt;

  /// Loads expectations from the bundled JSON asset
  ///
  /// Returns cached data if already loaded.
  /// Throws if the asset cannot be loaded or parsed.
  Future<Map<SleepAgeBand, SleepExpectations>> load() async {
    if (_cache != null) {
      return _cache!;
    }

    final jsonString = await rootBundle.loadString(_assetPath);
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;

    _schemaVersion = jsonData['schemaVersion'] as int?;
    _updatedAt = jsonData['updatedAt'] as String?;

    final bandsJson = jsonData['bands'] as List<dynamic>;
    final expectations = <SleepAgeBand, SleepExpectations>{};

    for (final bandJson in bandsJson) {
      final exp = SleepExpectations.fromJson(bandJson as Map<String, dynamic>);
      expectations[exp.ageBand] = exp;
    }

    _cache = expectations;
    _isLoaded = true;

    return expectations;
  }

  /// Gets expectations for a specific age band
  ///
  /// Returns null if not found or not loaded yet.
  /// Call [load] first to ensure data is available.
  SleepExpectations? getForBand(SleepAgeBand band) {
    return _cache?[band];
  }

  /// Gets expectations for a baby's birthDate
  ///
  /// Returns null if birthDate is null or band not found.
  SleepExpectations? getForBirthDate(DateTime? birthDate, {DateTime? referenceDate}) {
    if (birthDate == null) return null;

    final band = AgeCalculator.ageBand(birthDate, referenceDate: referenceDate);
    return getForBand(band);
  }

  /// Clears the cache (useful for testing)
  void clearCache() {
    _cache = null;
    _isLoaded = false;
    _schemaVersion = null;
    _updatedAt = null;
  }

  /// Returns all loaded expectations
  Map<SleepAgeBand, SleepExpectations>? get allExpectations => _cache;
}
