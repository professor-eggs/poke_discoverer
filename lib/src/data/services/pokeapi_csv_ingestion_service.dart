import '../models/cache_entry.dart';
import '../models/data_source_snapshot.dart';
import '../repositories/data_source_snapshot_repository.dart';
import '../sources/pokemon_cache_store.dart';
import '../../shared/clock.dart';
import 'pokemon_csv_loader.dart';
import 'pokemon_csv_parser.dart';

class PokeapiCsvIngestionService {
  PokeapiCsvIngestionService({
    required this.cacheStore,
    required this.snapshotRepository,
    required this.clock,
    required this.csvLoader,
  });

  final PokemonCacheStore cacheStore;
  final DataSourceSnapshotRepository snapshotRepository;
  final Clock clock;
  final CsvLoader csvLoader;

  Future<void> ingest({
    required DataSourceSnapshot snapshot,
  }) async {
    final needsImport = await snapshotRepository.needsImport(snapshot);
    if (!needsImport) {
      return;
    }

    final pokemonRows = await csvLoader.readCsv('pokemon.csv');
    final statsRows = await csvLoader.readCsv('pokemon_stats.csv');
    final statLookupRows = await csvLoader.readCsv('stats.csv');
    final pokemonTypesRows = await csvLoader.readCsv('pokemon_types.csv');
    final typeLookupRows = await csvLoader.readCsv('types.csv');
    final pokemonMovesRows = await csvLoader.readCsv('pokemon_moves.csv');
    final movesRows = await csvLoader.readCsv('moves.csv');
    final moveNamesRows = await csvLoader.readCsv('move_names.csv');
    final moveDamageClassesRows =
        await csvLoader.readCsv('move_damage_classes.csv');
    final moveLearnMethodsRows =
        await csvLoader.readCsv('pokemon_move_methods.csv');
    final moveLearnMethodProseRows =
        await csvLoader.readCsv('pokemon_move_method_prose.csv');

    final entities = PokemonCsvParser.parse(
      pokemon: pokemonRows,
      pokemonStats: statsRows,
      stats: statLookupRows,
      pokemonTypes: pokemonTypesRows,
      types: typeLookupRows,
      pokemonMoves: pokemonMovesRows,
      moves: movesRows,
      moveNames: moveNamesRows,
      moveDamageClasses: moveDamageClassesRows,
      moveLearnMethods: moveLearnMethodsRows,
      moveLearnMethodProse: moveLearnMethodProseRows,
    );

    final importTimestamp = clock.now();

    for (final pokemon in entities) {
      final cacheEntry = PokemonCacheEntry(
        pokemonId: pokemon.id,
        pokemon: pokemon,
        lastFetched: importTimestamp,
      );
      await cacheStore.saveEntry(cacheEntry);
    }

    await snapshotRepository.markImported(snapshot);
  }
}
