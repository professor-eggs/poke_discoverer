import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:poke_discoverer/src/data/models/data_source_snapshot.dart';
import 'package:poke_discoverer/src/data/sources/sqflite_data_source_snapshot_store.dart';

void main() {
  late SqfliteDataSourceSnapshotStore store;

  const kind = DataSourceKind.pokeapiCsv;
  final snapshot = DataSourceSnapshot(
    kind: kind,
    upstreamVersion: 'v2.0.0',
    checksum: 'abc123',
    packagedAt: DateTime.utc(2025, 1, 1, 12),
    importedAt: DateTime.utc(2025, 1, 2, 8),
    sourceUri: Uri.parse('https://example.com/pokeapi.csv'),
  );

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    store = SqfliteDataSourceSnapshotStore(
      databaseFactory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await store.clear();
    await store.close();
  });

  test('getSnapshot returns null when nothing stored', () async {
    final result = await store.getSnapshot(kind);
    expect(result, isNull);
  });

  test('upsertSnapshot persists record', () async {
    await store.upsertSnapshot(snapshot);

    final result = await store.getSnapshot(kind);
    expect(result, equals(snapshot));
  });

  test('upsertSnapshot overwrites existing record', () async {
    await store.upsertSnapshot(snapshot);
    final updated = snapshot.copyWith(
      upstreamVersion: 'v2.1.0',
      checksum: 'def456',
      importedAt: DateTime.utc(2025, 1, 3, 9),
    );

    await store.upsertSnapshot(updated);

    final result = await store.getSnapshot(kind);
    expect(result, equals(updated));
  });
}
