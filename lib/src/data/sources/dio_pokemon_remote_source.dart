import 'package:dio/dio.dart';

import '../mappers/pokemon_api_mapper.dart';
import '../models/pokemon_models.dart';
import '../../shared/data_result.dart';
import 'pokemon_remote_source.dart';

class DioPokemonRemoteSource implements PokemonRemoteSource {
  DioPokemonRemoteSource({
    required this.httpClient,
    required this.baseUrl,
  });

  final Dio httpClient;
  final Uri baseUrl;

  @override
  Future<DataResult<PokemonEntity>> fetchPokemonById(int pokemonId) async {
    final uri = baseUrl.resolve('pokemon/$pokemonId');

    try {
      final response = await httpClient.getUri<Map<String, dynamic>>(uri);
      final body = response.data;

      if (body == null) {
        return const DataResult.failure('Empty response');
      }

      try {
        final entity = PokemonApiMapper.fromJson(body);
        return DataResult.success(entity);
      } on FormatException catch (error) {
        return DataResult.failure(error.message);
      }
    } on DioException catch (error) {
      return DataResult.failure(error.message ?? 'Network error');
    } catch (error) {
      return DataResult.failure(error);
    }
  }
}
