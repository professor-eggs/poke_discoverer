import 'package:equatable/equatable.dart';

import 'pokemon_models.dart';

/// Cache entry for a single Pokémon payload.
class PokemonCacheEntry extends Equatable {
  const PokemonCacheEntry({
    required this.pokemonId,
    required this.pokemon,
    required this.lastFetched,
  });

  final int pokemonId;
  final PokemonEntity pokemon;
  final DateTime lastFetched;

  /// Returns whether this cache entry remains within [ttl] when evaluated at [now].
  bool isFresh({
    required DateTime now,
    required Duration ttl,
  }) {
    return now.isBefore(lastFetched.add(ttl));
  }

  @override
  List<Object?> get props => [pokemonId, pokemon, lastFetched];
}
