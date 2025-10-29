import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_discoverer/src/data/models/cache_entry.dart';
import 'package:poke_discoverer/src/data/models/pokemon_models.dart';
import 'package:poke_discoverer/src/data/repositories/pokemon_repository.dart';
import 'package:poke_discoverer/src/data/sources/pokemon_cache_store.dart';
import 'package:poke_discoverer/src/data/sources/pokemon_remote_source.dart';
import 'package:poke_discoverer/src/shared/clock.dart';
import 'package:poke_discoverer/src/shared/data_result.dart';

class _MockRemoteSource extends Mock implements PokemonRemoteSource {}

class _MockCacheStore extends Mock implements PokemonCacheStore {}

class _MockClock extends Mock implements Clock {}

void main() {
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
        sprites: [
          MediaAssetReference(
            assetId: 'sprite:pikachu',
            kind: MediaAssetKind.sprite,
          ),
        ],
        stats: [
          PokemonStatValue(statId: 'hp', baseValue: 35),
          PokemonStatValue(statId: 'atk', baseValue: 55),
        ],
        types: ['electric'],
      ),
    ],
  );

  group('PokemonRepository', () {
    late PokemonRemoteSource remoteSource;
    late PokemonCacheStore cacheStore;
    late Clock clock;
    late PokemonRepository repository;

    setUp(() {
      remoteSource = _MockRemoteSource();
      cacheStore = _MockCacheStore();
      clock = _MockClock();
      repository = PokemonRepository(
        remoteSource: remoteSource,
        cacheStore: cacheStore,
        clock: clock,
        cacheTtl: const Duration(days: 7),
      );
    });

    tearDown(() {
      reset(remoteSource);
      reset(cacheStore);
      reset(clock);
    });

    test(
      'fetchPokemon refreshes cache when remote fetch succeeds',
      () async {
        final now = DateTime.utc(2025, 1, 2, 3);
        when(() => clock.now()).thenReturn(now);
        when(() => remoteSource.fetchPokemonById(pokemonId))
            .thenAnswer((_) async => DataResult.success(demoPokemon));

        when(() => cacheStore.saveEntry(any())).thenAnswer((_) async {});

        final result = await repository.fetchPokemon(pokemonId);

        expect(result.isSuccess, isTrue);
        expect(result.requireValue(), equals(demoPokemon));

        final entryCapture = verify(
          () => cacheStore.saveEntry(captureAny()),
        ).captured;

        final savedEntry = entryCapture.single as PokemonCacheEntry;

        expect(savedEntry.pokemon, equals(demoPokemon));
        expect(savedEntry.pokemonId, pokemonId);
        expect(savedEntry.lastFetched, now);
      },
    );

    test(
      'fetchPokemon returns cached value when remote fails and cache is fresh',
      () async {
        final now = DateTime.utc(2025, 1, 2, 3);
        final cachedEntry = PokemonCacheEntry(
          pokemonId: pokemonId,
          pokemon: demoPokemon,
          lastFetched: now.subtract(const Duration(days: 2)),
        );

        when(() => clock.now()).thenReturn(now);
        when(() => remoteSource.fetchPokemonById(pokemonId))
            .thenAnswer((_) async => DataResult.failure('network down'));
        when(() => cacheStore.getEntry(pokemonId))
            .thenAnswer((_) async => cachedEntry);

        final result = await repository.fetchPokemon(pokemonId);

        expect(result.isSuccess, isTrue);
        expect(result.requireValue(), equals(demoPokemon));
        verifyNever(() => cacheStore.saveEntry(any()));
      },
    );

    test(
      'fetchPokemon evicts stale cache and surfaces failure when no fresh data',
      () async {
        final now = DateTime.utc(2025, 1, 10, 5);
        final staleEntry = PokemonCacheEntry(
          pokemonId: pokemonId,
          pokemon: demoPokemon,
          lastFetched: now.subtract(const Duration(days: 10)),
        );

        when(() => clock.now()).thenReturn(now);
        when(() => remoteSource.fetchPokemonById(pokemonId))
            .thenAnswer((_) async => DataResult.failure('timeout'));
        when(() => cacheStore.getEntry(pokemonId))
            .thenAnswer((_) async => staleEntry);
        when(() => cacheStore.removeEntry(pokemonId)).thenAnswer((_) async {});

        final result = await repository.fetchPokemon(pokemonId);

        expect(result.isSuccess, isFalse);
        expect(result.errorOrNull, equals('timeout'));
        verify(() => cacheStore.removeEntry(pokemonId)).called(1);
      },
    );

    test(
      'forceRefresh bypasses cache when requested',
      () async {
        final now = DateTime.utc(2025, 1, 12);
        when(() => clock.now()).thenReturn(now);
        when(() => remoteSource.fetchPokemonById(pokemonId))
            .thenAnswer((_) async => DataResult.success(demoPokemon));
        when(() => cacheStore.saveEntry(any())).thenAnswer((_) async {});

        final result =
            await repository.fetchPokemon(pokemonId, forceRefresh: true);

        expect(result.requireValue(), equals(demoPokemon));
        verifyNever(() => cacheStore.getEntry(any()));
        verify(() => remoteSource.fetchPokemonById(pokemonId)).called(1);
      },
    );
  });
}
