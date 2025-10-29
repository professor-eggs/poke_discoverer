import '../models/pokemon_models.dart';
import '../../shared/data_result.dart';

/// Fetches canonical Pokémon data from the remote PokéAPI (or mocked sources).
abstract class PokemonRemoteSource {
  Future<DataResult<PokemonEntity>> fetchPokemonById(int pokemonId);
}
