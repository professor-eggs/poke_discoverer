import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../models/cache_entry.dart';
import '../models/data_source_snapshot.dart';
import '../models/pokemon_models.dart';
import '../repositories/data_source_snapshot_repository.dart';
import '../sources/pokemon_cache_store.dart';
import '../../shared/clock.dart';

class PokeapiCsvIngestionService {
  PokeapiCsvIngestionService({
    required this.cacheStore,
    required this.snapshotRepository,
    required this.clock,
  });

  final PokemonCacheStore cacheStore;
  final DataSourceSnapshotRepository snapshotRepository;
  final Clock clock;

  Future<void> ingest({
    required String csvRootPath,
    required DataSourceSnapshot snapshot,
  }) async {
    final needsImport = await snapshotRepository.needsImport(snapshot);
    if (!needsImport) {
      return;
    }

    final pokemonRows = await _readCsvMaps(csvRootPath, 'pokemon.csv');
    final statsRows = await _readCsvMaps(csvRootPath, 'pokemon_stats.csv');
    final statLookupRows = await _readCsvMaps(csvRootPath, 'stats.csv');
    final pokemonTypesRows =
        await _readCsvMaps(csvRootPath, 'pokemon_types.csv');
    final typeLookupRows = await _readCsvMaps(csvRootPath, 'types.csv');

    final statNameMap = {
      for (final row in statLookupRows)
        _parseInt(row, 'id'): _normalizeStatIdentifier(row['identifier']),
    };

    final typeNameMap = {
      for (final row in typeLookupRows)
        _parseInt(row, 'id'): row['identifier']!.toLowerCase(),
    };

    final statsByPokemon = <int, List<PokemonStatValue>>{};
    for (final row in statsRows) {
      final pokemonId = _parseInt(row, 'pokemon_id');
      final statId = _parseInt(row, 'stat_id');
      final statName = statNameMap[statId];
      if (statName == null) continue;
      final statValue = _parseInt(row, 'base_stat');
      statsByPokemon.putIfAbsent(pokemonId, () => <PokemonStatValue>[]).add(
            PokemonStatValue(statId: statName, baseValue: statValue),
          );
    }

    final typeEntriesByPokemon = <int, List<_PokemonTypeEntry>>{};
    for (final row in pokemonTypesRows) {
      final pokemonId = _parseInt(row, 'pokemon_id');
      final typeId = _parseInt(row, 'type_id');
      final slot = _parseInt(row, 'slot');
      final typeName = typeNameMap[typeId];
      if (typeName == null) continue;
      typeEntriesByPokemon
          .putIfAbsent(pokemonId, () => <_PokemonTypeEntry>[])
          .add(_PokemonTypeEntry(slot: slot, name: typeName));
    }

    final importTimestamp = clock.now();

    for (final row in pokemonRows) {
      final pokemonId = _parseInt(row, 'id');
      final identifier = row['identifier']!;
      final speciesId = _parseInt(row, 'species_id');

      final stats = List<PokemonStatValue>.from(
        statsByPokemon[pokemonId] ?? const <PokemonStatValue>[],
        growable: false,
      );
      final typeEntries = List<_PokemonTypeEntry>.from(
        typeEntriesByPokemon[pokemonId] ?? const <_PokemonTypeEntry>[],
      )..sort((a, b) => a.slot.compareTo(b.slot));
      final types =
          typeEntries.map((entry) => entry.name).toList(growable: false);

      final spriteUrl = Uri.parse(
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$pokemonId.png',
      );

      final pokemon = PokemonEntity(
        id: pokemonId,
        name: identifier,
        speciesId: speciesId,
        forms: [
          PokemonFormEntity(
            id: pokemonId,
            name: identifier,
            isDefault: true,
            types: types,
            stats: stats,
            sprites: [
              MediaAssetReference(
                assetId: 'sprite:pokemon:$pokemonId:front-default',
                kind: MediaAssetKind.sprite,
                remoteUrl: spriteUrl,
              ),
            ],
          ),
        ],
      );

      final cacheEntry = PokemonCacheEntry(
        pokemonId: pokemonId,
        pokemon: pokemon,
        lastFetched: importTimestamp,
      );

      await cacheStore.saveEntry(cacheEntry);
    }

    await snapshotRepository.markImported(snapshot);
  }

  Future<List<Map<String, String>>> _readCsvMaps(
    String root,
    String fileName,
  ) async {
    final file = File(p.join(root, fileName));
    if (!await file.exists()) {
      throw FileSystemException('Missing CSV file', file.path);
    }
    final raw = await file.readAsString();
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((value) => value.toString()).toList();
    return rows
        .skip(1)
        .map((row) => Map<String, String>.fromIterables(
              headers,
              row.map((value) => value?.toString() ?? ''),
            ))
        .toList();
  }

  int _parseInt(Map<String, String> row, String key) {
    final value = row[key];
    if (value == null || value.isEmpty) {
      throw FormatException('Expected integer at key "$key"');
    }
    return int.parse(value);
  }

  String _normalizeStatIdentifier(String? identifier) {
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

