import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:poke_discoverer/src/data/models/data_source_snapshot.dart';
import 'package:poke_discoverer/src/data/repositories/data_source_snapshot_repository.dart';
import 'package:poke_discoverer/src/data/sources/data_source_snapshot_store.dart';
import 'package:poke_discoverer/src/shared/clock.dart';

class _MockSnapshotStore extends Mock implements DataSourceSnapshotStore {}

class _MockClock extends Mock implements Clock {}

void main() {
  final snapshot = DataSourceSnapshot(
    kind: DataSourceKind.pokeapiCsv,
    upstreamVersion: 'v2.0.0',
    checksum: 'abc123',
    packagedAt: DateTime.utc(2025, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(snapshot);
  });

  group('DataSourceSnapshotRepository', () {
    late DataSourceSnapshotStore store;
    late Clock clock;
    late DataSourceSnapshotRepository repository;

    setUp(() {
      store = _MockSnapshotStore();
      clock = _MockClock();
      repository = DataSourceSnapshotRepository(store: store, clock: clock);
    });

    tearDown(() {
      reset(store);
      reset(clock);
    });

    test('needsImport returns true when snapshot missing', () async {
      when(() => store.getSnapshot(snapshot.kind))
          .thenAnswer((_) async => null);

      final result = await repository.needsImport(snapshot);
      expect(result, isTrue);
    });

    test('needsImport returns false when checksum matches', () async {
      when(() => store.getSnapshot(snapshot.kind))
          .thenAnswer((_) async => snapshot);

      final result = await repository.needsImport(snapshot);
      expect(result, isFalse);
    });

    test('needsImport returns true when checksum differs', () async {
      final stored = snapshot.copyWith(checksum: 'different');
      when(() => store.getSnapshot(snapshot.kind))
          .thenAnswer((_) async => stored);

      final result = await repository.needsImport(snapshot);
      expect(result, isTrue);
    });

    test('markImported stamps importedAt and persists snapshot', () async {
      final now = DateTime.utc(2025, 1, 2, 3);
      when(() => clock.now()).thenReturn(now);
      when(() => store.upsertSnapshot(any())).thenAnswer((_) async {});

      final imported = await repository.markImported(snapshot);

      expect(imported.importedAt, equals(now));

      verify(() => store.upsertSnapshot(imported)).called(1);
    });
  });
}
