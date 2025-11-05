import 'package:flutter_test/flutter_test.dart';
import 'package:poke_discoverer/src/data/services/pokemon_csv_parser.dart';

void main() {
  group('PokemonCsvParser', () {
    test('includes version metadata with sorted details for moves', () {
      final entities = PokemonCsvParser.parse(
        pokemon: const [
          {'id': '1', 'identifier': 'bulbasaur', 'species_id': '1'},
          {'id': '4', 'identifier': 'charmander', 'species_id': '4'},
        ],
        pokemonStats: const [
          {'pokemon_id': '1', 'stat_id': '1', 'base_stat': '45'},
          {'pokemon_id': '4', 'stat_id': '1', 'base_stat': '39'},
        ],
        stats: const [
          {'id': '1', 'identifier': 'hp'},
        ],
        pokemonTypes: const [
          {'pokemon_id': '1', 'type_id': '12', 'slot': '1'},
          {'pokemon_id': '1', 'type_id': '4', 'slot': '2'},
          {'pokemon_id': '4', 'type_id': '10', 'slot': '1'},
        ],
        types: const [
          {'id': '1', 'identifier': 'normal'},
          {'id': '4', 'identifier': 'poison'},
          {'id': '10', 'identifier': 'fire'},
          {'id': '12', 'identifier': 'grass'},
        ],
        pokemonMoves: const [
          {
            'pokemon_id': '4',
            'version_group_id': '15',
            'move_id': '33',
            'pokemon_move_method_id': '1',
            'level': '1',
          },
          {
            'pokemon_id': '4',
            'version_group_id': '18',
            'move_id': '33',
            'pokemon_move_method_id': '1',
            'level': '5',
          },
          {
            'pokemon_id': '4',
            'version_group_id': '18',
            'move_id': '33',
            'pokemon_move_method_id': '4',
            'level': '0',
          },
        ],
        moves: const [
          {
            'id': '33',
            'identifier': 'tackle',
            'type_id': '1',
            'damage_class_id': '2',
            'power': '40',
            'pp': '35',
            'accuracy': '100',
          },
        ],
        moveNames: const [
          {'move_id': '33', 'local_language_id': '9', 'name': 'Tackle'},
        ],
        moveDamageClasses: const [
          {'id': '2', 'identifier': 'physical'},
        ],
        moveLearnMethods: const [
          {'id': '1', 'identifier': 'level-up'},
          {'id': '4', 'identifier': 'machine'},
        ],
        moveLearnMethodProse: const [
          {
            'pokemon_move_method_id': '1',
            'local_language_id': '9',
            'name': 'Level Up',
          },
          {
            'pokemon_move_method_id': '4',
            'local_language_id': '9',
            'name': 'Machine',
          },
        ],
        versionGroups: const [
          {
            'id': '15',
            'identifier': 'omega-ruby-alpha-sapphire',
            'generation_id': '6',
            'order': '15',
          },
          {
            'id': '18',
            'identifier': 'ultra-sun-ultra-moon',
            'generation_id': '7',
            'order': '18',
          },
        ],
        versionGroupRegions: const [
          {'version_group_id': '15', 'region_id': '2'},
          {'version_group_id': '18', 'region_id': '7'},
        ],
        versionGroupMethodAvailability: const [
          {'version_group_id': '15', 'pokemon_move_method_id': '1'},
          {'version_group_id': '15', 'pokemon_move_method_id': '4'},
          {'version_group_id': '18', 'pokemon_move_method_id': '1'},
          {'version_group_id': '18', 'pokemon_move_method_id': '4'},
        ],
        versions: const [
          {'id': '23', 'version_group_id': '15', 'identifier': 'omega-ruby'},
          {
            'id': '24',
            'version_group_id': '15',
            'identifier': 'alpha-sapphire',
          },
          {'id': '29', 'version_group_id': '18', 'identifier': 'ultra-sun'},
          {'id': '30', 'version_group_id': '18', 'identifier': 'ultra-moon'},
        ],
        versionNames: const [
          {'version_id': '23', 'local_language_id': '9', 'name': 'Omega Ruby'},
          {
            'version_id': '24',
            'local_language_id': '9',
            'name': 'Alpha Sapphire',
          },
          {'version_id': '29', 'local_language_id': '9', 'name': 'Ultra Sun'},
          {'version_id': '30', 'local_language_id': '9', 'name': 'Ultra Moon'},
        ],
      );

      expect(
        entities.map((pokemon) => pokemon.id).toList(),
        equals(<int>[1, 4]),
      );

      final charmander = entities.firstWhere(
        (pokemon) => pokemon.id == 4,
        orElse: () => throw StateError('Missing Charmander entity'),
      );
      final levelUpMove = charmander.defaultForm.moves.firstWhere(
        (move) => move.methodId == 'level-up',
      );
      final machineMove = charmander.defaultForm.moves.firstWhere(
        (move) => move.methodId == 'machine',
      );

      expect(levelUpMove.versionDetails, hasLength(2));
      expect(
        levelUpMove.versionDetails.map((d) => d.versionGroupName).toList(),
        equals(['Omega Ruby & Alpha Sapphire', 'Ultra Sun & Ultra Moon']),
      );
      expect(
        levelUpMove.versionDetails.map((d) => d.sortOrder).toList(),
        equals([15, 18]),
      );
      expect(levelUpMove.versionDetails.first.level, 1);
      expect(levelUpMove.versionDetails.last.level, 5);
      expect(levelUpMove.level, 1);

      expect(machineMove.versionDetails, hasLength(1));
      expect(machineMove.versionDetails.single.level, isNull);
      expect(machineMove.versionDetails.single.sortOrder, 18);
      expect(machineMove.level, isNull);
    });
  });
}
