import '../models/pokemon_models.dart';

class PokemonCsvParser {
  const PokemonCsvParser._();

  static List<PokemonEntity> parse({
    required List<Map<String, String>> pokemon,
    required List<Map<String, String>> pokemonStats,
    required List<Map<String, String>> stats,
    required List<Map<String, String>> pokemonTypes,
    required List<Map<String, String>> types,
    required List<Map<String, String>> pokemonMoves,
    required List<Map<String, String>> moves,
    required List<Map<String, String>> moveNames,
    required List<Map<String, String>> moveDamageClasses,
    required List<Map<String, String>> moveLearnMethods,
    required List<Map<String, String>> moveLearnMethodProse,
  }) {
    final statNameMap = {
      for (final row in stats)
        _parseInt(row, 'id'): _normalizeStatIdentifier(row['identifier']),
    };

    final typeNameMap = {
      for (final row in types)
        _parseInt(row, 'id'): row['identifier']!.toLowerCase(),
    };

    final statsByPokemon = <int, List<PokemonStatValue>>{};
    for (final row in pokemonStats) {
      final pokemonId = _parseInt(row, 'pokemon_id');
      final statId = _parseInt(row, 'stat_id');
      final statName = statNameMap[statId];
      if (statName == null) continue;
      final statValue = _parseInt(row, 'base_stat');
      statsByPokemon
          .putIfAbsent(pokemonId, () => <PokemonStatValue>[])
          .add(PokemonStatValue(statId: statName, baseValue: statValue));
    }

    final typeEntriesByPokemon = <int, List<_PokemonTypeEntry>>{};
    for (final row in pokemonTypes) {
      final pokemonId = _parseInt(row, 'pokemon_id');
      final typeId = _parseInt(row, 'type_id');
      final slot = _parseInt(row, 'slot');
      final typeName = typeNameMap[typeId];
      if (typeName == null) continue;
      typeEntriesByPokemon
          .putIfAbsent(pokemonId, () => <_PokemonTypeEntry>[])
          .add(_PokemonTypeEntry(slot: slot, name: typeName));
    }

    final moveInfoById = _buildMoveInfoMap(
      moves: moves,
      moveNames: moveNames,
      typeNameMap: typeNameMap,
      moveDamageClasses: moveDamageClasses,
    );
    final methodNameById = _buildMoveMethodMap(
      moveLearnMethods: moveLearnMethods,
      moveLearnMethodProse: moveLearnMethodProse,
    );
    final movesByPokemon = _groupMovesByPokemon(
      pokemonMoves: pokemonMoves,
      moveInfoById: moveInfoById,
      methodNameById: methodNameById,
    );

    final entities = <PokemonEntity>[];
    for (final row in pokemon) {
      final pokemonId = _parseInt(row, 'id');
      final identifier = row['identifier']!;
      final speciesId = _parseInt(row, 'species_id');

      final statsList = List<PokemonStatValue>.from(
        statsByPokemon[pokemonId] ?? const <PokemonStatValue>[],
        growable: false,
      );
      final typeEntries = List<_PokemonTypeEntry>.from(
        typeEntriesByPokemon[pokemonId] ?? const <_PokemonTypeEntry>[],
      )..sort((a, b) => a.slot.compareTo(b.slot));
      final typesList =
          typeEntries.map((entry) => entry.name).toList(growable: false);

      final spriteUrl = Uri.parse(
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$pokemonId.png',
      );

      entities.add(
        PokemonEntity(
          id: pokemonId,
          name: identifier,
          speciesId: speciesId,
          forms: [
            PokemonFormEntity(
              id: pokemonId,
              name: identifier,
              isDefault: true,
              types: typesList,
              stats: statsList,
              sprites: [
                MediaAssetReference(
                  assetId: 'sprite:pokemon:$pokemonId:front-default',
                  kind: MediaAssetKind.sprite,
                  remoteUrl: spriteUrl,
                ),
              ],
              moves: List<PokemonMoveSummary>.from(
                movesByPokemon[pokemonId] ?? const <PokemonMoveSummary>[],
                growable: false,
              ),
            ),
          ],
        ),
      );
    }

    return entities;
  }

  static int _parseInt(Map<String, String> row, String key) {
    final value = row[key];
    if (value == null || value.isEmpty) {
      throw FormatException('Expected integer at key "$key"');
    }
    return int.parse(value);
  }

  static String _normalizeStatIdentifier(String? identifier) {
    switch (identifier) {
      case 'hp':
        return 'hp';
      case 'attack':
        return 'atk';
      case 'defense':
        return 'def';
      case 'special-attack':
        return 'spa';
      case 'special-defense':
        return 'spd';
      case 'speed':
        return 'spe';
      default:
        return identifier ?? '';
    }
  }
}

class _PokemonTypeEntry {
  const _PokemonTypeEntry({
    required this.slot,
    required this.name,
  });

  final int slot;
  final String name;
}

class _MoveInfo {
  const _MoveInfo({
    required this.moveId,
    required this.name,
    required this.type,
    required this.damageClass,
    required this.power,
    required this.accuracy,
    required this.pp,
  });

  final int moveId;
  final String name;
  final String type;
  final String damageClass;
  final int? power;
  final int? accuracy;
  final int? pp;
}

class _MethodName {
  const _MethodName({
    required this.identifier,
    required this.displayName,
  });

  final String identifier;
  final String displayName;
}

class _MoveAggregate {
  _MoveAggregate({
    required this.moveId,
    required this.methodId,
  });

  final int moveId;
  final int methodId;
  int? _minLevel;

  void registerLevel(int? level) {
    if (level == null || level <= 0) return;
    if (_minLevel == null || level < _minLevel!) {
      _minLevel = level;
    }
  }

  int? get minLevel => _minLevel;
}

Map<int, _MoveInfo> _buildMoveInfoMap({
  required List<Map<String, String>> moves,
  required List<Map<String, String>> moveNames,
  required Map<int, String> typeNameMap,
  required List<Map<String, String>> moveDamageClasses,
}) {
  const englishLanguageId = 9;
  final englishNames = <int, String>{};
  for (final row in moveNames) {
    final languageId = PokemonCsvParser._parseInt(row, 'local_language_id');
    if (languageId != englishLanguageId) {
      continue;
    }
    final moveId = PokemonCsvParser._parseInt(row, 'move_id');
    englishNames[moveId] = row['name'] ?? '';
  }

  final damageClassMap = <int, String>{
    for (final row in moveDamageClasses)
      PokemonCsvParser._parseInt(row, 'id'):
          row['identifier']?.replaceAll('-', ' ') ?? ''
  };

  final map = <int, _MoveInfo>{};
  for (final row in moves) {
    final moveId = PokemonCsvParser._parseInt(row, 'id');
    final typeId = PokemonCsvParser._parseInt(row, 'type_id');
    final damageClassId = PokemonCsvParser._parseInt(row, 'damage_class_id');

    final typeName = typeNameMap[typeId];
    if (typeName == null) continue;

    int? parseNullableInt(String key) {
      final value = row[key];
      if (value == null || value.isEmpty || value == '0') {
        return null;
      }
      return int.tryParse(value);
    }

    final name = englishNames[moveId] ?? row['identifier'] ?? 'Unknown';
    map[moveId] = _MoveInfo(
      moveId: moveId,
      name: name,
      type: typeName,
      damageClass: damageClassMap[damageClassId] ?? 'status',
      power: parseNullableInt('power'),
      accuracy: parseNullableInt('accuracy'),
      pp: parseNullableInt('pp'),
    );
  }
  return map;
}

Map<int, _MethodName> _buildMoveMethodMap({
  required List<Map<String, String>> moveLearnMethods,
  required List<Map<String, String>> moveLearnMethodProse,
}) {
  const englishLanguageId = 9;
  final englishNames = <int, String>{
    for (final row in moveLearnMethodProse)
      if (PokemonCsvParser._parseInt(row, 'local_language_id') ==
          englishLanguageId)
        PokemonCsvParser._parseInt(row, 'pokemon_move_method_id'):
            row['name'] ?? ''
  };

  final map = <int, _MethodName>{};
  for (final row in moveLearnMethods) {
    final id = PokemonCsvParser._parseInt(row, 'id');
    final identifier = row['identifier'] ?? '';
    final rawName = englishNames[id];
    final displayName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : identifier.replaceAll('-', ' ');
    map[id] = _MethodName(
      identifier: identifier,
      displayName: displayName,
    );
  }
  return map;
}

Map<int, List<PokemonMoveSummary>> _groupMovesByPokemon({
  required List<Map<String, String>> pokemonMoves,
  required Map<int, _MoveInfo> moveInfoById,
  required Map<int, _MethodName> methodNameById,
}) {
  final grouped = <int, Map<String, _MoveAggregate>>{};

  for (final row in pokemonMoves) {
    final pokemonId = PokemonCsvParser._parseInt(row, 'pokemon_id');
    final moveId = PokemonCsvParser._parseInt(row, 'move_id');
    final methodId =
        PokemonCsvParser._parseInt(row, 'pokemon_move_method_id');
    final moveInfo = moveInfoById[moveId];
    final methodInfo = methodNameById[methodId];
    if (moveInfo == null || methodInfo == null) {
      continue;
    }
    final levelValue = row['level'];
    final level = levelValue == null || levelValue.isEmpty
        ? null
        : int.tryParse(levelValue);

    final key = '$moveId:$methodId';
    final pokemonMap =
        grouped.putIfAbsent(pokemonId, () => <String, _MoveAggregate>{});
    final aggregate = pokemonMap.putIfAbsent(
      key,
      () => _MoveAggregate(moveId: moveId, methodId: methodId),
    );
    aggregate.registerLevel(level);
  }

  final result = <int, List<PokemonMoveSummary>>{};
  grouped.forEach((pokemonId, aggregates) {
    final summaries = <PokemonMoveSummary>[];
    for (final aggregate in aggregates.values) {
      final moveInfo = moveInfoById[aggregate.moveId];
      final methodInfo = methodNameById[aggregate.methodId];
      if (moveInfo == null || methodInfo == null) continue;
      summaries.add(
        PokemonMoveSummary(
          moveId: moveInfo.moveId,
          methodId: methodInfo.identifier,
          name: _formatMoveName(moveInfo.name),
          method: methodInfo.displayName,
          type: moveInfo.type,
          damageClass: moveInfo.damageClass,
          level: aggregate.minLevel,
          power: moveInfo.power,
          accuracy: moveInfo.accuracy,
          pp: moveInfo.pp,
        ),
      );
    }

    summaries.sort((a, b) {
      int methodRank(String methodId) {
        switch (methodId) {
          case 'level-up':
            return 0;
          case 'machine':
            return 1;
          case 'tutor':
            return 2;
          case 'egg':
            return 3;
          default:
            return 4;
        }
      }

      final rankCompare =
          methodRank(a.methodId).compareTo(methodRank(b.methodId));
      if (rankCompare != 0) return rankCompare;

      final levelA = a.level ?? 999;
      final levelB = b.level ?? 999;
      final levelCompare = levelA.compareTo(levelB);
      if (levelCompare != 0) return levelCompare;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    result[pokemonId] = summaries;
  });

  return result;
}

String _formatMoveName(String name) {
  if (name.isEmpty) return name;
  return name
      .split('-')
      .map((part) =>
          part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
