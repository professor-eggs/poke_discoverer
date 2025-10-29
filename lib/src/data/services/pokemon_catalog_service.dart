import '../models/pokemon_models.dart';
import '../sources/pokemon_cache_store.dart';

class PokemonCatalogService {
  const PokemonCatalogService({
    required this.cacheStore,
  });

  final PokemonCacheStore cacheStore;

  Future<List<PokemonEntity>> getCachedPokemon({int? limit}) async {
    final entries = await cacheStore.getAllEntries(limit: limit);
    return entries.map((entry) => entry.pokemon).toList(growable: false);
  }
}
