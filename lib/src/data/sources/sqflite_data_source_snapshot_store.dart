import 'package:sqflite/sqflite.dart';

import '../mappers/data_source_snapshot_mapper.dart';
import '../models/data_source_snapshot.dart';
import 'data_source_snapshot_store.dart';

class SqfliteDataSourceSnapshotStore implements DataSourceSnapshotStore {
  SqfliteDataSourceSnapshotStore({
    required this.databaseFactory,
    required this.databaseName,
  });

  final DatabaseFactory databaseFactory;
  final String databaseName;

  Database? _database;

  Future<Database> _ensureDatabase() async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final db = await databaseFactory.openDatabase(
      databaseName,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS ${DataSourceSnapshotMapper.tableName()} (
              ${DataSourceSnapshotMapper.columnDataset} TEXT PRIMARY KEY,
              ${DataSourceSnapshotMapper.columnVersion} TEXT NOT NULL,
              ${DataSourceSnapshotMapper.columnChecksum} TEXT NOT NULL,
              ${DataSourceSnapshotMapper.columnPackagedAt} INTEGER NOT NULL,
              ${DataSourceSnapshotMapper.columnImportedAt} INTEGER,
              ${DataSourceSnapshotMapper.columnSourceUri} TEXT
            )
          ''');
        },
      ),
    );
    _database = db;
    return db;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  @override
  Future<DataSourceSnapshot?> getSnapshot(DataSourceKind kind) async {
    final db = await _ensureDatabase();
    final rows = await db.query(
      DataSourceSnapshotMapper.tableName(),
      where: '${DataSourceSnapshotMapper.columnDataset} = ?',
      whereArgs: [DataSourceSnapshotMapper.kindToDbValue(kind)],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DataSourceSnapshotMapper.fromDbRow(rows.first);
  }

  @override
  Future<void> upsertSnapshot(DataSourceSnapshot snapshot) async {
    final db = await _ensureDatabase();
    await db.insert(
      DataSourceSnapshotMapper.tableName(),
      DataSourceSnapshotMapper.toDbRow(snapshot),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear() async {
    final db = await _ensureDatabase();
    await db.delete(DataSourceSnapshotMapper.tableName());
  }
}
