import 'dart:io';
import 'dart:typed_data';

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/models/cache_entry.dart';
import 'data/models/data_source_snapshot.dart';
import 'data/repositories/data_source_snapshot_repository.dart';
import 'data/services/pokeapi_csv_ingestion_service.dart';
import 'data/services/pokemon_catalog_service.dart';
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
];

const _kSnapshotVersion = 'pokeapi-csv-2024-01-24';
final DateTime _kPackagedAt = DateTime.utc(2024, 1, 24);

class AppDependencies {
  AppDependencies({
    required this.cacheStore,
    required this.catalogService,
    required this.snapshotRepository,
  });

  final PokemonCacheStore cacheStore;
  final PokemonCatalogService catalogService;
  final DataSourceSnapshotRepository snapshotRepository;

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
    );
  }
}

late AppDependencies appDependencies;

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    appDependencies = AppDependencies.empty();
    return;
  }

  final csvRoot = await _resolveCsvRootPath();
  final checksum = await _computeChecksum(csvRoot, _kCsvFiles);

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

  final ingestionService = PokeapiCsvIngestionService(
    cacheStore: cacheStore,
    snapshotRepository: snapshotRepository,
    clock: const SystemClock(),
  );

  final snapshot = DataSourceSnapshot(
    kind: DataSourceKind.pokeapiCsv,
    upstreamVersion: _kSnapshotVersion,
    checksum: checksum,
    packagedAt: _kPackagedAt,
  );

  await ingestionService.ingest(
    csvRootPath: csvRoot,
    snapshot: snapshot,
  );

  final catalogService = PokemonCatalogService(cacheStore: cacheStore);
  appDependencies = AppDependencies(
    cacheStore: cacheStore,
    catalogService: catalogService,
    snapshotRepository: snapshotRepository,
  );
}

Future<String> _resolveCsvRootPath() async {
  final devPath = Directory(
    p.join(Directory.current.path, 'data', 'pokeapi-master', 'data', 'v2', 'csv'),
  );
  if (await devPath.exists()) {
    return devPath.path;
  }

  throw StateError(
    'Bundled PokeAPI CSV snapshot not found. Expected at '
    '${devPath.path}. Configure asset-based loading before shipping.',
  );
}

Future<String> _computeChecksum(
  String root,
  List<String> fileNames,
) async {
  final builder = BytesBuilder(copy: false);
  final sorted = [...fileNames]..sort();
  for (final fileName in sorted) {
    builder.add(fileName.codeUnits);
    builder.add(<int>[0]);
    final file = File(p.join(root, fileName));
    if (!await file.exists()) {
      throw FileSystemException('Missing CSV file for checksum', file.path);
    }
    builder.add(await file.readAsBytes());
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
