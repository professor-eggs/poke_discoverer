import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_discoverer/src/data/models/pokemon_models.dart';
import 'package:poke_discoverer/src/data/sources/dio_pokemon_remote_source.dart';
import 'package:poke_discoverer/src/shared/data_result.dart';

import '../../helpers/json_reader.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late Dio client;
  late DioPokemonRemoteSource remoteSource;

  setUp(() {
    client = _MockDio();
    remoteSource = DioPokemonRemoteSource(
      httpClient: client,
      baseUrl: Uri.parse('https://pokeapi.co/api/v2/'),
    );
  });

  group('DioPokemonRemoteSource', () {
    test('returns mapped PokemonEntity on success', () async {
      final fixture = readJsonFixtureMap('pokemon_25.json');
      final uri = Uri.parse('https://pokeapi.co/api/v2/pokemon/25');

      when(() => client.getUri<Map<String, dynamic>>(uri))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                data: fixture,
                statusCode: 200,
                requestOptions: RequestOptions(path: uri.toString()),
              ));

      final result = await remoteSource.fetchPokemonById(25);

      expect(result.isSuccess, isTrue);
      final pokemon = result.requireValue();
      expect(pokemon, isA<PokemonEntity>());
      expect(pokemon.id, 25);
      expect(pokemon.name, 'pikachu');
      expect(pokemon.forms.length, 2);
      final defaultForm = pokemon.defaultForm;
      expect(defaultForm.types, contains('electric'));
      expect(
        defaultForm.stats,
        contains(const PokemonStatValue(statId: 'hp', baseValue: 35)),
      );
      expect(defaultForm.sprites.single.remoteUrl, isNotNull);

      verify(() => client.getUri<Map<String, dynamic>>(uri)).called(1);
    });

    test('returns failure when response payload is empty', () async {
      final uri = Uri.parse('https://pokeapi.co/api/v2/pokemon/25');

      when(() => client.getUri<Map<String, dynamic>>(uri))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                data: null,
                statusCode: 200,
                requestOptions: RequestOptions(path: uri.toString()),
              ));

      final result = await remoteSource.fetchPokemonById(25);

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull, equals('Empty response'));
    });

    test('returns failure when Dio throws', () async {
      final uri = Uri.parse('https://pokeapi.co/api/v2/pokemon/25');
      when(() => client.getUri<Map<String, dynamic>>(uri)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: uri.toString()),
          message: 'Network down',
        ),
      );

      final result = await remoteSource.fetchPokemonById(25);

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull, equals('Network down'));
    });
  });
}
