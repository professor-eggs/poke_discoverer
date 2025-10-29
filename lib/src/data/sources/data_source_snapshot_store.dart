import '../models/data_source_snapshot.dart';

abstract class DataSourceSnapshotStore {
  Future<DataSourceSnapshot?> getSnapshot(DataSourceKind kind);
  Future<void> upsertSnapshot(DataSourceSnapshot snapshot);
  Future<void> clear();
}
