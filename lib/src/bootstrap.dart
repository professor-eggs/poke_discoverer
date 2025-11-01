import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'data/models/cache_entry.dart';
import 'data/models/data_source_snapshot.dart';
import 'data/repositories/data_source_snapshot_repository.dart';
import 'data/services/pokeapi_csv_ingestion_service.dart';
import 'data/services/pokemon_catalog_service.dart';
import 'data/services/pokemon_csv_loader.dart';
import 'data/services/pokemon_stat_calculator.dart';
import 'data/services/type_matchup_service.dart';
import 'data/sources/data_source_snapshot_store.dart';
import 'data/sources/pokemon_cache_store.dart';
import 'data/sources/sqflite_data_source_snapshot_store.dart';
import 'data/sources/sqflite_pokemon_cache_store.dart';
import 'shared/clock.dart';

const _kCsvFiles = <String>[
  'pokemon.csv',
  'pokemon_stats.csv',
  'stats.csv',
  'pokemon_types.csv',
  'types.csv',
  'type_efficacy.csv',
];

const _kSnapshotVersion = 'pokeapi-csv-2024-01-24';
final DateTime _kPackagedAt = DateTime.utc(2024, 1, 24);

class AppDependencies {
  AppDependencies({
    required this.cacheStore,
    required this.catalogService,
    required this.snapshotRepository,
    required this.csvLoader,
    required this.typeMatchupService,
    required this.statCalculator,
  });

  final PokemonCacheStore cacheStore;
  final PokemonCatalogService catalogService;
  final DataSourceSnapshotRepository snapshotRepository;
  final CsvLoader csvLoader;
  final TypeMatchupService typeMatchupService;
  final PokemonStatCalculator statCalculator;

  factory AppDependencies.empty() {
    const cacheStore = _NoopCacheStore();
    final snapshotRepository = DataSourceSnapshotRepository(
      store: _NoopSnapshotStore(),
      clock: const SystemClock(),
    );
    return AppDependencies(
      cacheStore: cacheStore,
      catalogService: PokemonCatalogService(cacheStore: cacheStore),
      snapshotRepository: snapshotRepository,
      csvLoader: _NoopCsvLoader(),
      typeMatchupService: const _NoopTypeMatchupService(),
      statCalculator: const PokemonStatCalculator(),
    );
  }
}

late AppDependencies appDependencies;

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  appDependencies = await initializeDependencies();
}

Future<AppDependencies> initializeDependencies({
  bool forceImport = false,
}) async {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  final csvLoader = await _createLoader();

  final databasesPath = await getDatabasesPath();
  final cacheDbPath = p.join(databasesPath, 'pokemon_cache.db');
  final snapshotDbPath = p.join(databasesPath, 'data_source_snapshots.db');

  final cacheStore = SqflitePokemonCacheStore(
    databaseFactory: databaseFactory,
    databaseName: cacheDbPath,
  );

  final snapshotStore = SqfliteDataSourceSnapshotStore(
    databaseFactory: databaseFactory,
    databaseName: snapshotDbPath,
  );

  final snapshotRepository = DataSourceSnapshotRepository(
    store: snapshotStore,
    clock: const SystemClock(),
  );

  if (forceImport) {
    await snapshotRepository.clear();
  }

  final checksum = await _computeChecksum(csvLoader, _kCsvFiles);

  final ingestionService = PokeapiCsvIngestionService(
    cacheStore: cacheStore,
    snapshotRepository: snapshotRepository,
    clock: const SystemClock(),
    csvLoader: csvLoader,
  );

  final snapshot = DataSourceSnapshot(
    kind: DataSourceKind.pokeapiCsv,
    upstreamVersion: _kSnapshotVersion,
    checksum: checksum,
    packagedAt: _kPackagedAt,
  );

  await ingestionService.ingest(snapshot: snapshot);

  return AppDependencies(
    cacheStore: cacheStore,
    catalogService: PokemonCatalogService(cacheStore: cacheStore),
    snapshotRepository: snapshotRepository,
    csvLoader: csvLoader,
    typeMatchupService: CsvTypeMatchupService(csvLoader: csvLoader),
    statCalculator: const PokemonStatCalculator(),
  );
}

Future<CsvLoader> _createLoader() async {
  if (kIsWeb) {
    return createCsvLoader(assetRoot: 'assets/pokeapi/csv');
  }
  final root = p.join('data', 'pokeapi-master', 'data', 'v2', 'csv');
  return createCsvLoader(filesystemRoot: root);
}

Future<String> _computeChecksum(
  CsvLoader loader,
  List<String> fileNames,
) async {
  final builder = BytesBuilder(copy: false);
  final sorted = [...fileNames]..sort();
  for (final fileName in sorted) {
    builder.add(fileName.codeUnits);
    builder.add(<int>[0]);
    final content = await loader.readCsvString(fileName);
    builder.add(content.codeUnits);
  }
  final digest = sha256.convert(builder.takeBytes());
  return digest.toString();
}

class _NoopCacheStore implements PokemonCacheStore {
  const _NoopCacheStore();

  @override
  Future<void> removeEntry(int pokemonId) async {}

  @override
  Future<void> saveEntry(PokemonCacheEntry entry) async {}

  @override
  Future<PokemonCacheEntry?> getEntry(int pokemonId) async => null;

  @override
  Future<List<PokemonCacheEntry>> getAllEntries({int? limit}) async => const [];
}

class _NoopSnapshotStore implements DataSourceSnapshotStore {
  @override
  Future<void> clear() async {}

  @override
  Future<DataSourceSnapshot?> getSnapshot(DataSourceKind kind) async => null;

  @override
  Future<void> upsertSnapshot(DataSourceSnapshot snapshot) async {}
}

class _NoopCsvLoader implements CsvLoader {
  const _NoopCsvLoader();

  @override
  Future<List<Map<String, String>>> readCsv(String fileName) async => const [];

  @override
  Future<String> readCsvString(String fileName) async => '';
}

class _NoopTypeMatchupService implements TypeMatchupService {
  const _NoopTypeMatchupService();

  @override
  Future<TypeMatchupSummary> defensiveSummary(
    List<String> defendingTypes,
  ) async {
    return const TypeMatchupSummary(
      weaknesses: <TypeEffectivenessEntry>[],
      resistances: <TypeEffectivenessEntry>[],
      immunities: <TypeEffectivenessEntry>[],
    );
  }

  @override
  Future<TypeCoverageSummary> teamCoverage(
    List<List<String>> defendingTypesList,
  ) async {
    return const TypeCoverageSummary(
      sharedWeaknesses: <TypeEffectivenessEntry>[],
      uncoveredWeaknesses: <TypeEffectivenessEntry>[],
      resistances: <TypeEffectivenessEntry>[],
      immunities: <TypeEffectivenessEntry>[],
    );
  }
}
