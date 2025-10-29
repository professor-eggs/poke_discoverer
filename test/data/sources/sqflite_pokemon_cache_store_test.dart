import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:poke_discoverer/src/data/models/cache_entry.dart';
import 'package:poke_discoverer/src/data/models/pokemon_models.dart';
import 'package:poke_discoverer/src/data/sources/sqflite_pokemon_cache_store.dart';

void main() {
  late SqflitePokemonCacheStore store;

  const pokemonId = 25;
  const demoPokemon = PokemonEntity(
    id: pokemonId,
    name: 'pikachu',
    speciesId: 25,
    forms: [
      PokemonFormEntity(
        id: 1,
        name: 'pikachu-base',
        isDefault: true,
        types: ['electric'],
        stats: [
          PokemonStatValue(statId: 'hp', baseValue: 35),
          PokemonStatValue(statId: 'atk', baseValue: 55),
        ],
        sprites: [
          MediaAssetReference(
            assetId: 'sprite:pikachu',
            kind: MediaAssetKind.sprite,
            remoteUrl: Uri.parse(
              'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png',
            ),
          ),
        ],
      ),
    ],
  );

  PokemonCacheEntry newEntry(DateTime timestamp) => PokemonCacheEntry(
        pokemonId: pokemonId,
        pokemon: demoPokemon,
        lastFetched: timestamp,
      );

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    store = SqflitePokemonCacheStore(
      databaseFactory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await store.close();
  });

  test('getEntry returns null when cache miss', () async {
    final result = await store.getEntry(pokemonId);
    expect(result, isNull);
  });

  test('saveEntry persists and getEntry returns value', () async {
    final timestamp = DateTime.utc(2025, 1, 1, 12, 30);
    final entry = newEntry(timestamp);

    await store.saveEntry(entry);

    final cached = await store.getEntry(pokemonId);
    expect(cached, equals(entry));
  });

  test('saveEntry overwrites existing data', () async {
    final first = newEntry(DateTime.utc(2025, 1, 1));
    final second = newEntry(DateTime.utc(2025, 1, 2));

    await store.saveEntry(first);
    await store.saveEntry(second);

    final cached = await store.getEntry(pokemonId);
    expect(cached, equals(second));
  });

  test('removeEntry deletes cache row', () async {
    final entry = newEntry(DateTime.utc(2025, 1, 3));
    await store.saveEntry(entry);

    await store.removeEntry(pokemonId);

    final cached = await store.getEntry(pokemonId);
    expect(cached, isNull);
  });
}
