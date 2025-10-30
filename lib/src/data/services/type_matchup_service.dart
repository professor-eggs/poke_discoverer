import 'dart:async';

import 'pokemon_csv_loader.dart';

/// Describes the effectiveness of an attacking type against a defending Pokémon.
class TypeEffectivenessEntry {
  const TypeEffectivenessEntry({
    required this.type,
    required this.multiplier,
  });

  final String type;
  final double multiplier;
}

/// Summarises how effective incoming attacks are against a defending Pokémon.
class TypeMatchupSummary {
  const TypeMatchupSummary({
    required this.weaknesses,
    required this.resistances,
    required this.immunities,
  });

  final List<TypeEffectivenessEntry> weaknesses;
  final List<TypeEffectivenessEntry> resistances;
  final List<TypeEffectivenessEntry> immunities;

  bool get isEmpty =>
      weaknesses.isEmpty && resistances.isEmpty && immunities.isEmpty;
}

class TypeCoverageSummary {
  const TypeCoverageSummary({
    required this.sharedWeaknesses,
    required this.uncoveredWeaknesses,
    required this.resistances,
    required this.immunities,
  });

  final List<TypeEffectivenessEntry> sharedWeaknesses;
  final List<TypeEffectivenessEntry> uncoveredWeaknesses;
  final List<TypeEffectivenessEntry> resistances;
  final List<TypeEffectivenessEntry> immunities;

  bool get isEmpty =>
      sharedWeaknesses.isEmpty &&
      uncoveredWeaknesses.isEmpty &&
      resistances.isEmpty &&
      immunities.isEmpty;
}

/// Contract for resolving type effectiveness.
abstract class TypeMatchupService {
  Future<TypeMatchupSummary> defensiveSummary(List<String> defendingTypes);
  Future<TypeCoverageSummary> teamCoverage(
    List<List<String>> defendingTypesList,
  );
}

/// Computes type matchups from the PokéAPI CSV exports.
class CsvTypeMatchupService implements TypeMatchupService {
  CsvTypeMatchupService({required this.csvLoader});

  final CsvLoader csvLoader;

  Future<Map<String, Map<String, double>>>? _matrixFuture;
  Map<String, Map<String, double>>? _matrixCache;

  @override
  Future<TypeMatchupSummary> defensiveSummary(
    List<String> defendingTypes,
  ) async {
    final matrix = await _loadMatrix();
    if (matrix.isEmpty || defendingTypes.isEmpty) {
      return const TypeMatchupSummary(
        weaknesses: <TypeEffectivenessEntry>[],
        resistances: <TypeEffectivenessEntry>[],
        immunities: <TypeEffectivenessEntry>[],
      );
    }

    final normalizedTypes = defendingTypes
        .map((type) => type.toLowerCase())
        .where((type) => matrix.values.first.containsKey(type))
        .toList(growable: false);

    if (normalizedTypes.isEmpty) {
      return const TypeMatchupSummary(
        weaknesses: <TypeEffectivenessEntry>[],
        resistances: <TypeEffectivenessEntry>[],
        immunities: <TypeEffectivenessEntry>[],
      );
    }

    final weaknesses = <TypeEffectivenessEntry>[];
    final resistances = <TypeEffectivenessEntry>[];
    final immunities = <TypeEffectivenessEntry>[];

    for (final attackType in matrix.keys) {
      var multiplier = 1.0;
      for (final defendType in normalizedTypes) {
        final factor =
            matrix[attackType]?[defendType] ?? 1.0; // default neutral
        multiplier *= factor;
      }

      multiplier = _normalizeMultiplier(multiplier);
      if (multiplier == 0) {
        immunities.add(
          TypeEffectivenessEntry(type: attackType, multiplier: multiplier),
        );
      } else if (multiplier > 1) {
        weaknesses.add(
          TypeEffectivenessEntry(type: attackType, multiplier: multiplier),
        );
      } else if (multiplier < 1) {
        resistances.add(
          TypeEffectivenessEntry(type: attackType, multiplier: multiplier),
        );
      }
    }

    weaknesses.sort(
      (a, b) => b.multiplier.compareTo(a.multiplier),
    );
    resistances.sort(
      (a, b) => a.multiplier.compareTo(b.multiplier),
    );

    return TypeMatchupSummary(
      weaknesses: weaknesses,
      resistances: resistances,
      immunities: immunities,
    );
  }

  @override
  Future<TypeCoverageSummary> teamCoverage(
    List<List<String>> defendingTypesList,
  ) async {
    if (defendingTypesList.isEmpty) {
      return const TypeCoverageSummary(
        sharedWeaknesses: <TypeEffectivenessEntry>[],
        uncoveredWeaknesses: <TypeEffectivenessEntry>[],
        resistances: <TypeEffectivenessEntry>[],
        immunities: <TypeEffectivenessEntry>[],
      );
    }

    final summaries = await Future.wait(
      defendingTypesList.map(defensiveSummary),
    );

    return _buildTeamCoverage(summaries, defendingTypesList.length);
  }

  double _normalizeMultiplier(double value) {
    // Expected multipliers are 0, 0.25, 0.5, 1, 2, 4.
    const known = <double>[0, 0.25, 0.5, 1, 2, 4];
    for (final candidate in known) {
      if ((value - candidate).abs() < 0.001) {
        return candidate;
      }
    }
    return double.parse(value.toStringAsFixed(2));
  }

  Future<Map<String, Map<String, double>>> _loadMatrix() {
    _matrixFuture ??= _buildMatrix();
    return _matrixFuture!;
  }

  Future<Map<String, Map<String, double>>> _buildMatrix() async {
    final existing = _matrixCache;
    if (existing != null) {
      return existing;
    }

    final typesRows = await csvLoader.readCsv('types.csv');
    final efficacyRows = await csvLoader.readCsv('type_efficacy.csv');

    final idToType = <int, String>{};
    for (final row in typesRows) {
      final id = int.tryParse(row['id'] ?? '');
      final identifier = row['identifier'];
      if (id == null || identifier == null || identifier.isEmpty) {
        continue;
      }
      // Ignore special placeholder types that are not relevant for matchups.
      if (identifier == 'shadow' || identifier == 'unknown') {
        continue;
      }
      idToType[id] = identifier.toLowerCase();
    }

    final matrix = <String, Map<String, double>>{};

    for (final row in efficacyRows) {
      final damageTypeId = int.tryParse(row['damage_type_id'] ?? '');
      final targetTypeId = int.tryParse(row['target_type_id'] ?? '');
      final damageFactor = int.tryParse(row['damage_factor'] ?? '');
      if (damageTypeId == null ||
          targetTypeId == null ||
          damageFactor == null) {
        continue;
      }

      final damageType = idToType[damageTypeId];
      final targetType = idToType[targetTypeId];
      if (damageType == null || targetType == null) {
        continue;
      }

      final multiplier = damageFactor / 100.0;
      matrix
          .putIfAbsent(damageType, () => <String, double>{})
          .putIfAbsent(targetType, () => multiplier);
      matrix[damageType]![targetType] = multiplier;
    }

    // Ensure all type keys exist even if no relations were recorded.
    for (final type in idToType.values) {
      matrix.putIfAbsent(type, () => <String, double>{});
      for (final target in idToType.values) {
        matrix[type]!.putIfAbsent(target, () => 1.0);
      }
    }

    _matrixCache = matrix;
    return matrix;
  }

  TypeCoverageSummary _buildTeamCoverage(
    List<TypeMatchupSummary> summaries,
    int teamSize,
  ) {
    final weaknessCount = <String, int>{};
    final weaknessMax = <String, double>{};
    final resistanceCount = <String, int>{};
    final resistanceMin = <String, double>{};
    final immunityTypes = <String>{};

    for (final summary in summaries) {
      for (final entry in summary.weaknesses) {
        weaknessCount.update(entry.type, (value) => value + 1, ifAbsent: () => 1);
        final current = weaknessMax[entry.type];
        if (current == null || entry.multiplier > current) {
          weaknessMax[entry.type] = entry.multiplier;
        }
      }

      for (final entry in summary.resistances) {
        resistanceCount.update(entry.type, (value) => value + 1, ifAbsent: () => 1);
        final current = resistanceMin[entry.type];
        if (current == null || entry.multiplier < current) {
          resistanceMin[entry.type] = entry.multiplier;
        }
      }

      for (final entry in summary.immunities) {
        immunityTypes.add(entry.type);
      }
    }

    final sharedWeaknesses = <TypeEffectivenessEntry>[];
    final uncoveredWeaknesses = <TypeEffectivenessEntry>[];

    weaknessCount.forEach((type, count) {
      final multiplier = weaknessMax[type] ?? 2;
      if (count == teamSize) {
        sharedWeaknesses.add(
          TypeEffectivenessEntry(type: type, multiplier: multiplier),
        );
      }
      final hasCoverage =
          immunityTypes.contains(type) || resistanceCount.containsKey(type);
      if (!hasCoverage) {
        uncoveredWeaknesses.add(
          TypeEffectivenessEntry(type: type, multiplier: multiplier),
        );
      }
    });

    final resistances = resistanceMin.entries
        .map(
          (entry) => TypeEffectivenessEntry(
            type: entry.key,
            multiplier: entry.value,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.multiplier.compareTo(b.multiplier));

    final immunities = immunityTypes
        .map(
          (type) => TypeEffectivenessEntry(type: type, multiplier: 0),
        )
        .toList(growable: false)
      ..sort((a, b) => a.type.compareTo(b.type));

    sharedWeaknesses.sort(
      (a, b) => b.multiplier.compareTo(a.multiplier),
    );
    uncoveredWeaknesses.sort(
      (a, b) => b.multiplier.compareTo(a.multiplier),
    );

    return TypeCoverageSummary(
      sharedWeaknesses: sharedWeaknesses,
      uncoveredWeaknesses: uncoveredWeaknesses,
      resistances: resistances,
      immunities: immunities,
    );
  }
}
