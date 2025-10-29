import '../models/data_source_snapshot.dart';

class DataSourceSnapshotMapper {
  const DataSourceSnapshotMapper._();

  static const _table = 'data_source_snapshot';
  static const columnDataset = 'dataset';
  static const columnVersion = 'upstream_version';
  static const columnChecksum = 'checksum';
  static const columnPackagedAt = 'packaged_at_ms';
  static const columnImportedAt = 'imported_at_ms';
  static const columnSourceUri = 'source_uri';

  static Map<String, Object?> toDbRow(DataSourceSnapshot snapshot) {
    return {
      columnDataset: kindToDbValue(snapshot.kind),
      columnVersion: snapshot.upstreamVersion,
      columnChecksum: snapshot.checksum,
      columnPackagedAt: snapshot.packagedAt.millisecondsSinceEpoch,
      columnImportedAt: snapshot.importedAt?.millisecondsSinceEpoch,
      columnSourceUri: snapshot.sourceUri?.toString(),
    };
  }

  static DataSourceSnapshot fromDbRow(Map<String, Object?> row) {
    return DataSourceSnapshot(
      kind: kindFromDbValue(row[columnDataset] as String),
      upstreamVersion: row[columnVersion] as String,
      checksum: row[columnChecksum] as String,
      packagedAt: DateTime.fromMillisecondsSinceEpoch(
        row[columnPackagedAt] as int,
        isUtc: true,
      ),
      importedAt: _readNullableMillis(row[columnImportedAt]),
      sourceUri: _readNullableUri(row[columnSourceUri]),
    );
  }

  static String tableName() => _table;

  static DateTime? _readNullableMillis(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return null;
  }

  static Uri? _readNullableUri(Object? value) {
    if (value is String && value.isNotEmpty) {
      return Uri.tryParse(value);
    }
    return null;
  }

  static String kindToDbValue(DataSourceKind kind) {
    switch (kind) {
      case DataSourceKind.pokeapiCsv:
        return 'pokeapi_csv';
    }
    throw ArgumentError('Unsupported data source kind: $kind');
  }

  static DataSourceKind kindFromDbValue(String value) {
    switch (value) {
      case 'pokeapi_csv':
        return DataSourceKind.pokeapiCsv;
    }
    throw ArgumentError.value(value, 'value', 'Unknown data source kind');
  }
}
