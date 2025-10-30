import '../models/pokemon_models.dart';
import '../sources/pokemon_cache_store.dart';

class PokemonCatalogService {
  const PokemonCatalogService({required this.cacheStore});

  final PokemonCacheStore cacheStore;

  Future<List<PokemonEntity>> getCachedPokemon({int? limit}) async {
    final entries = await cacheStore.getAllEntries(limit: limit);
    return entries.map((entry) => entry.pokemon).toList(growable: false);
  }

  Future<PokemonEntity?> getPokemonById(int pokemonId) async {
    final entry = await cacheStore.getEntry(pokemonId);
    return entry?.pokemon;
  }

  Future<List<PokemonEntity>> getPokemonByIds(List<int> pokemonIds) async {
    final entities = <PokemonEntity>[];
    for (final id in pokemonIds) {
      final entry = await cacheStore.getEntry(id);
      if (entry != null) {
        entities.add(entry.pokemon);
      }
    }
    return entities;
  }
}
