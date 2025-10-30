import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:poke_discoverer/src/data/models/cache_entry.dart';
import 'package:poke_discoverer/src/data/models/data_source_snapshot.dart';
import 'package:poke_discoverer/src/data/models/pokemon_models.dart';
import 'package:poke_discoverer/src/data/repositories/data_source_snapshot_repository.dart';
import 'package:poke_discoverer/src/data/services/pokeapi_csv_ingestion_service.dart';
import 'package:poke_discoverer/src/data/services/pokemon_csv_loader.dart';
import 'package:poke_discoverer/src/data/sources/pokemon_cache_store.dart';
import 'package:poke_discoverer/src/shared/clock.dart';

class _MockCacheStore extends Mock implements PokemonCacheStore {}

class _MockSnapshotRepository extends Mock
    implements DataSourceSnapshotRepository {}

class _MockClock extends Mock implements Clock {}

void main() {
  late PokemonCacheStore cacheStore;
  late DataSourceSnapshotRepository snapshotRepository;
  late Clock clock;
  late PokeapiCsvIngestionService service;
  late CsvLoader csvLoader;

  final snapshot = DataSourceSnapshot(
    kind: DataSourceKind.pokeapiCsv,
    upstreamVersion: 'v2.0.0',
    checksum: 'abc123',
    packagedAt: DateTime.utc(2025, 1, 1),
  );

  const fixturesRoot = 'test/fixtures/pokeapi_csv';

  setUpAll(() {
    registerFallbackValue(
      PokemonCacheEntry(
        pokemonId: 0,
        pokemon: const PokemonEntity(
          id: 0,
          name: 'placeholder',
          speciesId: 0,
          forms: [],
        ),
        lastFetched: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    registerFallbackValue(snapshot);
  });

  setUp(() {
    cacheStore = _MockCacheStore();
    snapshotRepository = _MockSnapshotRepository();
    clock = _MockClock();
    csvLoader = _FixtureCsvLoader(rootPath: fixturesRoot);
    service = PokeapiCsvIngestionService(
      cacheStore: cacheStore,
      snapshotRepository: snapshotRepository,
      clock: clock,
      csvLoader: csvLoader,
    );
  });

  tearDown(() {
    reset(cacheStore);
    reset(snapshotRepository);
    reset(clock);
  });

  test('ingest imports Pokemon data when snapshot changes', () async {
    when(() => snapshotRepository.needsImport(any()))
        .thenAnswer((_) async => true);
    final now = DateTime.utc(2025, 1, 2);
    when(() => clock.now()).thenReturn(now);
    final savedEntries = <PokemonCacheEntry>[];
    when(() => cacheStore.saveEntry(any())).thenAnswer((invocation) async {
      savedEntries.add(invocation.positionalArguments.first as PokemonCacheEntry);
    });
    when(() => snapshotRepository.markImported(any()))
        .thenAnswer((invocation) async {
      final incoming = invocation.positionalArguments.first as DataSourceSnapshot;
      return incoming.copyWith(importedAt: now);
    });

    await service.ingest(snapshot: snapshot);

    expect(savedEntries, hasLength(2));
    verify(() => snapshotRepository.needsImport(any())).called(1);

    final bulbasaur = savedEntries.firstWhere(
      (entry) => entry.pokemonId == 1,
    );
    expect(bulbasaur.pokemon.name, 'bulbasaur');
    final bulbaForm = bulbasaur.pokemon.forms.single;
    expect(bulbaForm.types, ['grass', 'poison']);
    expect(
      bulbaForm.stats,
      contains(const PokemonStatValue(statId: 'hp', baseValue: 45)),
    );
    expect(
      bulbaForm.sprites.single.remoteUrl?.toString(),
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1.png',
    );
    expect(bulbasaur.lastFetched, now);

    verify(() => snapshotRepository.markImported(any())).called(1);
  });

  test('ingest skips when snapshot checksum unchanged', () async {
    when(() => snapshotRepository.needsImport(any()))
        .thenAnswer((_) async => false);

    await service.ingest(snapshot: snapshot);

    verifyNever(() => cacheStore.saveEntry(any()));
    verifyNever(() => snapshotRepository.markImported(any()));
  });
}

class _FixtureCsvLoader implements CsvLoader {
  _FixtureCsvLoader({required this.rootPath});

  final String rootPath;

  @override
  Future<List<Map<String, String>>> readCsv(String fileName) async {
    final raw = await readCsvString(fileName);
    final rows =
        const CsvToListConverter(eol: '\n').convert(raw.replaceAll('\r', ''));
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((value) => value.toString()).toList();
    return rows
        .skip(1)
        .map(
          (row) => Map<String, String>.fromIterables(
            headers,
            row.map((value) => value?.toString() ?? ''),
          ),
        )
        .toList();
  }

  @override
  Future<String> readCsvString(String fileName) async {
    final file = File(p.join(rootPath, fileName));
    if (!await file.exists()) {
      throw FileSystemException('Missing CSV fixture', file.path);
    }
    return file.readAsString();
  }
}
