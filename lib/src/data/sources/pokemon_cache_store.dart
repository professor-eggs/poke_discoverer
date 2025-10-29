import '../models/cache_entry.dart';

/// Persistent cache for Pokémon payloads.
abstract class PokemonCacheStore {
  Future<PokemonCacheEntry?> getEntry(int pokemonId);
  Future<void> saveEntry(PokemonCacheEntry entry);
  Future<void> removeEntry(int pokemonId);
}
