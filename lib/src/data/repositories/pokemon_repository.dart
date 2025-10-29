import '../models/cache_entry.dart';
import '../models/pokemon_models.dart';
import '../sources/pokemon_cache_store.dart';
import '../sources/pokemon_remote_source.dart';
import '../../shared/clock.dart';
import '../../shared/data_result.dart';

class PokemonRepository {
  PokemonRepository({
    required this.remoteSource,
    required this.cacheStore,
    required this.clock,
    this.cacheTtl = const Duration(days: 7),
  });

  final PokemonRemoteSource remoteSource;
  final PokemonCacheStore cacheStore;
  final Clock clock;
  final Duration cacheTtl;

  Future<DataResult<PokemonEntity>> fetchPokemon(
    int pokemonId, {
    bool forceRefresh = false,
  }) async {
    final now = clock.now();

    if (!forceRefresh) {
      final cachedEntry = await cacheStore.getEntry(pokemonId);
      if (cachedEntry != null) {
        if (cachedEntry.isFresh(now: now, ttl: cacheTtl)) {
          return DataResult.success(cachedEntry.pokemon);
        }
        await cacheStore.removeEntry(pokemonId);
      }
    }

    final remoteResult = await remoteSource.fetchPokemonById(pokemonId);
    if (remoteResult.isSuccess) {
      final pokemon = remoteResult.requireValue();
      await cacheStore.saveEntry(
        PokemonCacheEntry(
          pokemonId: pokemonId,
          pokemon: pokemon,
          lastFetched: now,
        ),
      );
      return DataResult.success(pokemon);
    }

    return remoteResult;
  }
}
