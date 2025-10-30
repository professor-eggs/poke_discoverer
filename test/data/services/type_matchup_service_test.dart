import 'package:flutter_test/flutter_test.dart';

import 'package:poke_discoverer/src/data/services/pokemon_csv_loader.dart';
import 'package:poke_discoverer/src/data/services/type_matchup_service.dart';

void main() {
  group('CsvTypeMatchupService', () {
    late CsvTypeMatchupService service;

    setUp(() {
      service = CsvTypeMatchupService(csvLoader: _FakeCsvLoader());
    });

    test('calculates defensive summary for dual-type Pokémon', () async {
      final summary =
          await service.defensiveSummary(const ['grass', 'poison']);

      expect(summary.weaknesses.length, 4);
      expect(_multiplier(summary.weaknesses, 'fire'), 2);
      expect(_multiplier(summary.weaknesses, 'ice'), 2);
      expect(_multiplier(summary.weaknesses, 'flying'), 2);
      expect(_multiplier(summary.weaknesses, 'psychic'), 2);

      expect(summary.resistances.length, 5);
      expect(_multiplier(summary.resistances, 'water'), 0.5);
      expect(_multiplier(summary.resistances, 'electric'), 0.5);
      expect(_multiplier(summary.resistances, 'grass'), 0.25);
      expect(_multiplier(summary.resistances, 'fighting'), 0.5);
      expect(_multiplier(summary.resistances, 'fairy'), 0.5);

      expect(summary.immunities, isEmpty);
    });

    test('returns empty summary when types are unknown', () async {
      final summary = await service.defensiveSummary(const ['shadow']);
      expect(summary.isEmpty, isTrue);
    });
  });
}

double? _multiplier(List<TypeEffectivenessEntry> entries, String type) {
  for (final entry in entries) {
    if (entry.type == type) {
      return entry.multiplier;
    }
  }
  return null;
}

class _FakeCsvLoader implements CsvLoader {
  const _FakeCsvLoader();

  static const List<Map<String, String>> _types = [
    {'id': '2', 'identifier': 'fighting'},
    {'id': '3', 'identifier': 'flying'},
    {'id': '4', 'identifier': 'poison'},
    {'id': '10', 'identifier': 'fire'},
    {'id': '11', 'identifier': 'water'},
    {'id': '12', 'identifier': 'grass'},
    {'id': '13', 'identifier': 'electric'},
    {'id': '14', 'identifier': 'psychic'},
    {'id': '15', 'identifier': 'ice'},
    {'id': '18', 'identifier': 'fairy'},
  ];

  static const List<Map<String, String>> _efficacy = [
    {'damage_type_id': '10', 'target_type_id': '12', 'damage_factor': '200'},
    {'damage_type_id': '15', 'target_type_id': '12', 'damage_factor': '200'},
    {'damage_type_id': '3', 'target_type_id': '12', 'damage_factor': '200'},
    {'damage_type_id': '14', 'target_type_id': '4', 'damage_factor': '200'},
    {'damage_type_id': '11', 'target_type_id': '12', 'damage_factor': '50'},
    {'damage_type_id': '13', 'target_type_id': '12', 'damage_factor': '50'},
    {'damage_type_id': '12', 'target_type_id': '12', 'damage_factor': '50'},
    {'damage_type_id': '12', 'target_type_id': '4', 'damage_factor': '50'},
    {'damage_type_id': '2', 'target_type_id': '4', 'damage_factor': '50'},
    {'damage_type_id': '18', 'target_type_id': '4', 'damage_factor': '50'},
  ];

  @override
  Future<List<Map<String, String>>> readCsv(String fileName) async {
    switch (fileName) {
      case 'types.csv':
        return _types;
      case 'type_efficacy.csv':
        return _efficacy;
      default:
        return const <Map<String, String>>[];
    }
  }

  @override
  Future<String> readCsvString(String fileName) async => '';
}
