import '../models/pokemon_models.dart';

class PokemonCsvParser {
  const PokemonCsvParser._();

  static List<PokemonEntity> parse({
    required List<Map<String, String>> pokemon,
    required List<Map<String, String>> pokemonStats,
    required List<Map<String, String>> stats,
    required List<Map<String, String>> pokemonTypes,
    required List<Map<String, String>> types,
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
