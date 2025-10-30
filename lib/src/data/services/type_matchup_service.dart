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

/// Contract for resolving type effectiveness.
abstract class TypeMatchupService {
  Future<TypeMatchupSummary> defensiveSummary(List<String> defendingTypes);
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
}
