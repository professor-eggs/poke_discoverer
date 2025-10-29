import '../models/data_source_snapshot.dart';
import '../sources/data_source_snapshot_store.dart';
import '../../shared/clock.dart';

class DataSourceSnapshotRepository {
  DataSourceSnapshotRepository({
    required this.store,
    required this.clock,
  });

  final DataSourceSnapshotStore store;
  final Clock clock;

  Future<DataSourceSnapshot?> currentSnapshot(DataSourceKind kind) {
    return store.getSnapshot(kind);
  }

  Future<bool> needsImport(DataSourceSnapshot snapshot) async {
    final existing = await store.getSnapshot(snapshot.kind);
    if (existing == null) {
      return true;
    }
    return existing.checksum != snapshot.checksum;
  }

  Future<DataSourceSnapshot> markImported(DataSourceSnapshot snapshot) async {
    final importedSnapshot = snapshot.copyWith(importedAt: clock.now());
    await store.upsertSnapshot(importedSnapshot);
    return importedSnapshot;
  }

  Future<void> clear() => store.clear();
}
