import 'package:sqflite/sqflite.dart';

import '../mappers/pokemon_cache_mapper.dart';
import '../models/cache_entry.dart';
import 'pokemon_cache_store.dart';

class SqflitePokemonCacheStore implements PokemonCacheStore {
  SqflitePokemonCacheStore({
    required this.databaseFactory,
    required this.databaseName,
  });

  final DatabaseFactory databaseFactory;
  final String databaseName;

  static const _tableName = 'pokemon_cache';
  static const _columnId = 'pokemon_id';

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
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS $_tableName (
              $_columnId INTEGER PRIMARY KEY,
              pokemon_json TEXT NOT NULL,
              last_fetched_ms INTEGER NOT NULL
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
  Future<PokemonCacheEntry?> getEntry(int pokemonId) async {
    final db = await _ensureDatabase();
    final rows = await db.query(
      _tableName,
      where: '$_columnId = ?',
      whereArgs: [pokemonId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    return PokemonCacheMapper.fromDbRow(rows.first);
  }

  @override
  Future<void> removeEntry(int pokemonId) async {
    final db = await _ensureDatabase();
    await db.delete(
      _tableName,
      where: '$_columnId = ?',
      whereArgs: [pokemonId],
    );
  }

  @override
  Future<void> saveEntry(PokemonCacheEntry entry) async {
    final db = await _ensureDatabase();
    await db.insert(
      _tableName,
      PokemonCacheMapper.toDbRow(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<PokemonCacheEntry>> getAllEntries({int? limit}) async {
    final db = await _ensureDatabase();
    final rows = await db.query(
      _tableName,
      orderBy: '$_columnId ASC',
      limit: limit,
    );
    return rows.map(PokemonCacheMapper.fromDbRow).toList(growable: false);
  }
}
