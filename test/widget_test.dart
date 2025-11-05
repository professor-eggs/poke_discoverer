import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poke_discoverer/main.dart';
import 'package:poke_discoverer/src/bootstrap.dart';
import 'package:poke_discoverer/src/data/models/cache_entry.dart';
import 'package:poke_discoverer/src/data/models/data_source_snapshot.dart';
import 'package:poke_discoverer/src/data/models/pokemon_models.dart';
import 'package:poke_discoverer/src/data/repositories/data_source_snapshot_repository.dart';
import 'package:poke_discoverer/src/data/services/pokemon_catalog_service.dart';
import 'package:poke_discoverer/src/data/services/pokemon_csv_loader.dart';
import 'package:poke_discoverer/src/data/services/pokemon_stat_calculator.dart';
import 'package:poke_discoverer/src/data/services/type_matchup_service.dart';
import 'package:poke_discoverer/src/data/sources/data_source_snapshot_store.dart';
import 'package:poke_discoverer/src/data/sources/pokemon_cache_store.dart';
import 'package:poke_discoverer/src/presentation/comparison/pokemon_comparison_page.dart'
    show
        LevelControlMode,
        PokemonComparisonPage,
        initializeComparisonDependencies,
        kLevelControlMode,
        resetInitializeComparisonDependencies;
import 'package:poke_discoverer/src/presentation/widgets/sprite_avatar.dart';
import 'package:poke_discoverer/src/shared/clock.dart';

void main() {
  setUp(() {
    appDependencies = AppDependencies.empty();
  });

  testWidgets('Displays placeholder when no cached Pokemon', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Pokemon Catalog'), findsOneWidget);
    expect(find.text('Charmander'), findsNothing);
    expect(
      find.text(
        'No cached Pokemon available yet. Seed the snapshot to view entries.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Filters catalog by search term and type', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Charmander'), findsOneWidget);

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('Squirtle'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('pokemonCatalogSearchField')),
      'char',
    );
    await tester.pumpAndSettle();

    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);
    expect(find.text('Squirtle'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Fire'));
    await tester.pumpAndSettle();

    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);
    expect(find.text('Squirtle'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Water'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No Pokemon match the current filters. Adjust search or clear filters.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Grass'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Poison'));
    await tester.pumpAndSettle();

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Charmander'), findsNothing);
    expect(find.text('Squirtle'), findsNothing);

    await tester.tap(find.text('Bulbasaur').first);
    await tester.pumpAndSettle();

    expect(find.text('Pokemon #001'), findsOneWidget);
    expect(find.text('Base stats'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Type matchups'), findsOneWidget);
    expect(find.text('Weak to'), findsOneWidget);
    expect(find.text('Resists'), findsOneWidget);
    expect(find.text('Fire x2'), findsOneWidget);
    expect(find.text('Water x0.5'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('Detail page moves tab lists moves', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bulbasaur'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Moves'));
    await tester.pumpAndSettle();

    expect(find.text('Level Up'), findsWidgets);
    expect(find.text('Tackle'), findsOneWidget);
    expect(find.text('Lv 1'), findsOneWidget);
  });

  testWidgets(
    'Detail recommended moves respond to preset and version filters',
    (tester) async {
      final pokemon = _samplePokemon();
      _arrangeCatalogDependencies(pokemon);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bulbasaur'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moves'));
      await tester.pumpAndSettle();

      expect(find.text('Recommended moves'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Balanced'), findsOneWidget);
      expect(find.text('Solar Beam'), findsNothing);
      expect(find.text('Vine Whip'), findsWidgets);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All methods').first);
      await tester.pumpAndSettle();

      expect(find.text('Solar Beam'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('detailPresetDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physical sweeper').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Balanced'), findsNothing);
      expect(find.widgetWithText(Chip, 'Atk+'), findsOneWidget);
      expect(find.text('Solar Beam'), findsWidgets);

      final omegaChipFinder = find
          .widgetWithText(ChoiceChip, 'Omega Ruby & Alpha Sapphire')
          .first;
      await tester.ensureVisible(omegaChipFinder);
      await tester.tap(omegaChipFinder);
      await tester.pumpAndSettle();

      expect(find.text('Solar Beam'), findsNothing);
      expect(find.text('Vine Whip'), findsWidgets);
    },
  );

  testWidgets(
    'Moves tab version filter hides unavailable methods and restores selection',
    (tester) async {
      final pokemon = _samplePokemon();
      _arrangeCatalogDependencies(pokemon);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bulbasaur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moves'));
      await tester.pumpAndSettle();

      final machineFinder = find.widgetWithText(ChoiceChip, 'Machine');

      await tester.tap(machineFinder.first);
      await tester.pumpAndSettle();
      expect(find.text('Echoed Voice'), findsWidgets);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Omega Ruby & Alpha Sapphire').first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Echoed Voice'), findsNothing);
      final allMethodsChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'All methods'),
      );
      expect(allMethodsChip.selected, isTrue);
      expect(machineFinder, findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All versions'));
      await tester.pumpAndSettle();

      expect(find.text('Echoed Voice'), findsWidgets);
      final machineChipAfter = tester.widget<ChoiceChip>(machineFinder.first);
      expect(machineChipAfter.selected, isTrue);
    },
  );

  testWidgets('Shows selection bar after selecting a Pokemon', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    final compareButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Compare (1)'),
    );
    expect(compareButton.onPressed, isNull);
    expect(find.text('#001 Bulbasaur'), findsOneWidget);
  });

  testWidgets('Catalog renders sprite avatars for each Pokemon', (
    tester,
  ) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(SpriteAvatar), findsNWidgets(pokemon.length));
  });

  testWidgets('Opens detail while selection is active', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final infoButton = find.byTooltip('View details').first;
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(find.text('Pokemon #001'), findsOneWidget);
    expect(find.text('Base stats'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('Sort controls reorder catalog entries by stat', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dex number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speed').last);
    await tester.pumpAndSettle();

    final bulbasaurTop = tester
        .getTopLeft(find.byKey(const ValueKey('pokemon-1')))
        .dy;
    final charmanderTop = tester
        .getTopLeft(find.byKey(const ValueKey('pokemon-4')))
        .dy;
    final squirtleTop = tester
        .getTopLeft(find.byKey(const ValueKey('pokemon-7')))
        .dy;

    expect(squirtleTop, lessThan(bulbasaurTop));
    expect(bulbasaurTop, lessThan(charmanderTop));

    await tester.tap(find.byTooltip('Ascending'));
    await tester.pumpAndSettle();

    final bulbasaurDesc = tester
        .getTopLeft(find.byKey(const ValueKey('pokemon-1')))
        .dy;
    final charmanderDesc = tester
        .getTopLeft(find.byKey(const ValueKey('pokemon-4')))
        .dy;
    final squirtleDesc = tester
        .getTopLeft(find.byKey(const ValueKey('pokemon-7')))
        .dy;

    expect(charmanderDesc, lessThan(bulbasaurDesc));
    expect(bulbasaurDesc, lessThan(squirtleDesc));
  });

  testWidgets('PokemonComparisonPage renders stats table', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1, 4])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compare (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-card-1')), findsOneWidget);
    expect(find.text('Recommended moves'), findsWidgets);
  });

  testWidgets('Computed stats mode recalculates totals by level', (
    tester,
  ) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1, 4, 7])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Computed'));
    await tester.pumpAndSettle();

    if (kLevelControlMode == LevelControlMode.buttonCluster) {
      expect(find.text('Level 50'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, '+1'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, '+5'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, '+10'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, '-1'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, '-5'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, '-10'), findsWidgets);

      Future<void> press(String label) async {
        final buttonFinder = find.widgetWithText(OutlinedButton, label).first;
        await tester.ensureVisible(buttonFinder);
        final buttonWidget = tester.widget<OutlinedButton>(buttonFinder);
        buttonWidget.onPressed?.call();
        await tester.pumpAndSettle();
      }

      await press('+1');

      expect(find.text('Level 51'), findsOneWidget);

      await press('+5');
      expect(find.text('Level 56'), findsOneWidget);

      await press('-10');
      expect(find.text('Level 46'), findsOneWidget);
    } else {
      final inputField = find.byType(TextField).first;
      await tester.enterText(inputField, '65');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.textContaining('Level 65'), findsOneWidget);
    }
  });

  testWidgets('Comparison sort supports stat keys and direction', (
    tester,
  ) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1, 4, 7])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('comparisonSortDropdown')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HP').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('comparisonSortDirection')));
    await tester.pumpAndSettle();

    final bulbasaurLeft = tester
        .getTopLeft(find.byKey(const ValueKey('comparison-card-1')))
        .dx;
    final squirtleLeft = tester
        .getTopLeft(find.byKey(const ValueKey('comparison-card-7')))
        .dx;
    final charmanderLeft = tester
        .getTopLeft(find.byKey(const ValueKey('comparison-card-4')))
        .dx;

    expect(bulbasaurLeft, lessThan(squirtleLeft));
    expect(squirtleLeft, lessThan(charmanderLeft));
  });

  testWidgets('Comparison cards render type matchup preview', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1, 4])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Weak to'), findsWidgets);
    expect(find.textContaining('Weak to Fire x2'), findsWidgets);
    expect(find.textContaining('Resists Water x0.5'), findsWidgets);
  });

  testWidgets('Recommended moves react to preset changes', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Computed'));
    await tester.pumpAndSettle();

    expect(find.text('Recommended moves'), findsWidgets);
    expect(find.text('Vine Whip'), findsWidgets);
    expect(find.text('Solar Beam'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('presetDropdown-1')));
    await tester.tap(find.byKey(const ValueKey('presetDropdown-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Special sweeper').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('versionDropdown-1')));
    await tester.tap(find.byKey(const ValueKey('versionDropdown-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ultra Sun & Ultra Moon').last);
    await tester.pumpAndSettle();

    expect(find.text('Solar Beam'), findsWidgets);
  });

  testWidgets('Global level control updates all cards', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1, 4, 7])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Computed'));
    await tester.pumpAndSettle();

    expect(find.text('All cards using level 50.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('comparisonGlobalLevelField')),
      '60',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Level 60'), findsNWidgets(3));
    expect(find.text('All cards using level 60.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('comparisonGlobalPreset100')));
    await tester.pumpAndSettle();

    expect(find.text('Level 100'), findsNWidgets(3));
    expect(find.text('All cards using level 100.'), findsOneWidget);
  });

  testWidgets('Preset dropdown updates stat summary', (tester) async {
    final pokemon = _samplePokemon();
    _arrangeCatalogDependencies(pokemon);

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1, 4, 7])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Computed'));
    await tester.pumpAndSettle();

    final presetDropdown = find.byKey(const ValueKey('presetDropdown-1')).first;
    await tester.ensureVisible(presetDropdown);
    await tester.tap(presetDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Physical sweeper').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Phys. Sweep'), findsWidgets);
    expect(find.text('+Atk / max Speed EVs, Adamant nature.'), findsOneWidget);
  });

  testWidgets('Comparison page surfaces missing data banner and seeds cache', (
    tester,
  ) async {
    final allPokemon = _samplePokemon();
    final initialPokemon = allPokemon.take(2).toList();
    _arrangeCatalogDependencies(initialPokemon);

    addTearDown(resetInitializeComparisonDependencies);

    var seedCalls = 0;
    initializeComparisonDependencies = ({bool forceImport = false}) async {
      seedCalls++;
      expect(forceImport, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final seededCache = _InMemoryPokemonCacheStore.fromPokemon(allPokemon);
      return AppDependencies(
        cacheStore: seededCache,
        catalogService: PokemonCatalogService(cacheStore: seededCache),
        snapshotRepository: DataSourceSnapshotRepository(
          store: _NoopSnapshotStore(),
          clock: const SystemClock(),
        ),
        csvLoader: const _StubCsvLoader(),
        typeMatchupService: const _FakeTypeMatchupService(),
        statCalculator: const PokemonStatCalculator(),
      );
    };

    await tester.pumpWidget(
      MaterialApp(home: PokemonComparisonPage(pokemonIds: const [1, 4, 7])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('#007'), findsOneWidget);
    expect(find.textContaining('missing from the local cache'), findsOneWidget);
    expect(find.text('Import cached data'), findsOneWidget);

    await tester.tap(find.text('Import cached data'));
    await tester.pump();

    await tester.pumpAndSettle();

    expect(seedCalls, 1);
    expect(find.textContaining('missing from the local cache'), findsNothing);
    expect(find.text('Squirtle'), findsWidgets);
  });
}

PokemonEntity _buildPokemon({
  required int id,
  required String name,
  required List<String> types,
  required List<int> stats,
  List<PokemonMoveSummary>? moves,
}) {
  final statIds = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
  final statValues = <PokemonStatValue>[
    for (var i = 0; i < stats.length; i++)
      PokemonStatValue(statId: statIds[i], baseValue: stats[i]),
  ];

  final effectiveMoves = moves == null
      ? <PokemonMoveSummary>[
          PokemonMoveSummary(
            moveId: id * 100 + 1,
            methodId: 'level-up',
            name: 'tackle',
            method: 'Level up',
            type: 'normal',
            damageClass: 'physical',
            versionDetails: const [
              PokemonMoveVersionDetail(
                versionGroupId: 15,
                versionGroupName: 'Omega Ruby & Alpha Sapphire',
                sortOrder: 15,
                level: 1,
              ),
              PokemonMoveVersionDetail(
                versionGroupId: 18,
                versionGroupName: 'Ultra Sun & Ultra Moon',
                sortOrder: 18,
                level: 5,
              ),
            ],
            level: 1,
            power: 40,
            accuracy: 100,
            pp: 35,
          ),
          PokemonMoveSummary(
            moveId: id * 100 + 2,
            methodId: 'machine',
            name: 'echoed voice',
            method: 'Machine',
            type: 'normal',
            damageClass: 'special',
            versionDetails: const [
              PokemonMoveVersionDetail(
                versionGroupId: 18,
                versionGroupName: 'Ultra Sun & Ultra Moon',
                sortOrder: 18,
                level: null,
              ),
            ],
            level: null,
            power: 40,
            accuracy: 100,
            pp: 15,
          ),
        ]
      : List<PokemonMoveSummary>.from(moves);

  if (types.contains('grass')) {
    effectiveMoves
      ..add(
        PokemonMoveSummary(
          moveId: id * 100 + 3,
          methodId: 'level-up',
          name: 'vine whip',
          method: 'Level up',
          type: 'grass',
          damageClass: 'physical',
          versionDetails: const [
            PokemonMoveVersionDetail(
              versionGroupId: 15,
              versionGroupName: 'Omega Ruby & Alpha Sapphire',
              sortOrder: 15,
              level: 9,
            ),
          ],
          level: 9,
          power: 45,
          accuracy: 100,
          pp: 25,
        ),
      )
      ..add(
        PokemonMoveSummary(
          moveId: id * 100 + 4,
          methodId: 'machine',
          name: 'solar beam',
          method: 'Machine',
          type: 'grass',
          damageClass: 'special',
          versionDetails: const [
            PokemonMoveVersionDetail(
              versionGroupId: 18,
              versionGroupName: 'Ultra Sun & Ultra Moon',
              sortOrder: 18,
              level: null,
            ),
          ],
          level: null,
          power: 120,
          accuracy: 100,
          pp: 10,
        ),
      );
  } else if (types.contains('fire')) {
    effectiveMoves
      ..add(
        PokemonMoveSummary(
          moveId: id * 100 + 3,
          methodId: 'level-up',
          name: 'flame charge',
          method: 'Level up',
          type: 'fire',
          damageClass: 'physical',
          versionDetails: const [
            PokemonMoveVersionDetail(
              versionGroupId: 15,
              versionGroupName: 'Omega Ruby & Alpha Sapphire',
              sortOrder: 15,
              level: 15,
            ),
          ],
          level: 15,
          power: 50,
          accuracy: 100,
          pp: 20,
        ),
      )
      ..add(
        PokemonMoveSummary(
          moveId: id * 100 + 4,
          methodId: 'machine',
          name: 'flamethrower',
          method: 'Machine',
          type: 'fire',
          damageClass: 'special',
          versionDetails: const [
            PokemonMoveVersionDetail(
              versionGroupId: 18,
              versionGroupName: 'Ultra Sun & Ultra Moon',
              sortOrder: 18,
              level: null,
            ),
          ],
          level: null,
          power: 90,
          accuracy: 100,
          pp: 15,
        ),
      );
  } else if (types.contains('water')) {
    effectiveMoves
      ..add(
        PokemonMoveSummary(
          moveId: id * 100 + 3,
          methodId: 'level-up',
          name: 'aqua tail',
          method: 'Level up',
          type: 'water',
          damageClass: 'physical',
          versionDetails: const [
            PokemonMoveVersionDetail(
              versionGroupId: 15,
              versionGroupName: 'Omega Ruby & Alpha Sapphire',
              sortOrder: 15,
              level: 21,
            ),
          ],
          level: 21,
          power: 90,
          accuracy: 90,
          pp: 10,
        ),
      )
      ..add(
        PokemonMoveSummary(
          moveId: id * 100 + 4,
          methodId: 'machine',
          name: 'hydro pump',
          method: 'Machine',
          type: 'water',
          damageClass: 'special',
          versionDetails: const [
            PokemonMoveVersionDetail(
              versionGroupId: 18,
              versionGroupName: 'Ultra Sun & Ultra Moon',
              sortOrder: 18,
              level: null,
            ),
          ],
          level: null,
          power: 110,
          accuracy: 80,
          pp: 5,
        ),
      );
  }

  return PokemonEntity(
    id: id,
    name: name,
    speciesId: id,
    forms: [
      PokemonFormEntity(
        id: id,
        name: name,
        isDefault: true,
        types: types,
        stats: statValues,
        sprites: const [
          MediaAssetReference(assetId: 'sprite', kind: MediaAssetKind.sprite),
        ],
        moves: effectiveMoves,
      ),
    ],
  );
}

List<PokemonEntity> _samplePokemon() => <PokemonEntity>[
  _buildPokemon(
    id: 1,
    name: 'bulbasaur',
    types: const ['grass', 'poison'],
    stats: const [45, 49, 49, 65, 65, 45],
  ),
  _buildPokemon(
    id: 4,
    name: 'charmander',
    types: const ['fire'],
    stats: const [39, 52, 43, 60, 50, 65],
  ),
  _buildPokemon(
    id: 7,
    name: 'squirtle',
    types: const ['water'],
    stats: const [44, 48, 65, 50, 64, 43],
  ),
];

class _InMemoryPokemonCacheStore implements PokemonCacheStore {
  _InMemoryPokemonCacheStore.fromPokemon(Iterable<PokemonEntity> pokemon) {
    for (final entity in pokemon) {
      _entries[entity.id] = PokemonCacheEntry(
        pokemonId: entity.id,
        pokemon: entity,
        lastFetched: DateTime.utc(2024, 1, 1),
      );
    }
  }

  final Map<int, PokemonCacheEntry> _entries = <int, PokemonCacheEntry>{};

  @override
  Future<PokemonCacheEntry?> getEntry(int pokemonId) async =>
      _entries[pokemonId];

  @override
  Future<void> removeEntry(int pokemonId) async {
    _entries.remove(pokemonId);
  }

  @override
  Future<void> saveEntry(PokemonCacheEntry entry) async {
    _entries[entry.pokemonId] = entry;
  }

  @override
  Future<List<PokemonCacheEntry>> getAllEntries({int? limit}) async {
    final items = _entries.values.toList()
      ..sort((a, b) => a.pokemonId.compareTo(b.pokemonId));
    if (limit != null && limit < items.length) {
      return items.sublist(0, limit);
    }
    return items;
  }
}

class _NoopSnapshotStore implements DataSourceSnapshotStore {
  DataSourceSnapshot? _snapshot;

  @override
  Future<void> clear() async {
    _snapshot = null;
  }

  @override
  Future<DataSourceSnapshot?> getSnapshot(DataSourceKind kind) async =>
      _snapshot;

  @override
  Future<void> upsertSnapshot(DataSourceSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class _StubCsvLoader implements CsvLoader {
  const _StubCsvLoader();

  @override
  Future<List<Map<String, String>>> readCsv(String fileName) async => const [];

  @override
  Future<String> readCsvString(String fileName) async => '';
}

class _FakeTypeMatchupService implements TypeMatchupService {
  const _FakeTypeMatchupService();

  @override
  Future<TypeMatchupSummary> defensiveSummary(
    List<String> defendingTypes,
  ) async {
    final normalized = defendingTypes.map((type) => type.toLowerCase()).toSet();

    if (normalized.contains('grass') && normalized.contains('poison')) {
      return const TypeMatchupSummary(
        weaknesses: <TypeEffectivenessEntry>[
          TypeEffectivenessEntry(type: 'fire', multiplier: 2),
          TypeEffectivenessEntry(type: 'ice', multiplier: 2),
          TypeEffectivenessEntry(type: 'flying', multiplier: 2),
          TypeEffectivenessEntry(type: 'psychic', multiplier: 2),
        ],
        resistances: <TypeEffectivenessEntry>[
          TypeEffectivenessEntry(type: 'water', multiplier: 0.5),
          TypeEffectivenessEntry(type: 'electric', multiplier: 0.5),
          TypeEffectivenessEntry(type: 'grass', multiplier: 0.25),
          TypeEffectivenessEntry(type: 'fighting', multiplier: 0.5),
          TypeEffectivenessEntry(type: 'fairy', multiplier: 0.5),
        ],
        immunities: <TypeEffectivenessEntry>[],
      );
    }

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
    final summaries = await Future.wait(
      defendingTypesList.map(defensiveSummary),
    );
    final teamSize = defendingTypesList.length;
    final weaknessCount = <String, int>{};
    final weaknessMax = <String, double>{};
    final resistanceCount = <String, int>{};
    final resistanceMin = <String, double>{};
    final immunityTypes = <String>{};

    for (final summary in summaries) {
      for (final entry in summary.weaknesses) {
        weaknessCount.update(
          entry.type,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final current = weaknessMax[entry.type];
        if (current == null || entry.multiplier > current) {
          weaknessMax[entry.type] = entry.multiplier;
        }
      }
      for (final entry in summary.resistances) {
        resistanceCount.update(
          entry.type,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final current = resistanceMin[entry.type];
        if (current == null || entry.multiplier < current) {
          resistanceMin[entry.type] = entry.multiplier;
        }
      }
      for (final entry in summary.immunities) {
        immunityTypes.add(entry.type);
      }
    }

    final sharedWeaknesses = <TypeEffectivenessEntry>[];
    final uncoveredWeaknesses = <TypeEffectivenessEntry>[];

    weaknessCount.forEach((type, count) {
      final multiplier = weaknessMax[type] ?? 2;
      if (count == teamSize) {
        sharedWeaknesses.add(
          TypeEffectivenessEntry(type: type, multiplier: multiplier),
        );
      }
      final hasCoverage =
          immunityTypes.contains(type) || resistanceCount.containsKey(type);
      if (!hasCoverage) {
        uncoveredWeaknesses.add(
          TypeEffectivenessEntry(type: type, multiplier: multiplier),
        );
      }
    });

    final resistances =
        resistanceMin.entries
            .map(
              (entry) => TypeEffectivenessEntry(
                type: entry.key,
                multiplier: entry.value,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.multiplier.compareTo(b.multiplier));

    final immunities =
        immunityTypes
            .map((type) => TypeEffectivenessEntry(type: type, multiplier: 0))
            .toList(growable: false)
          ..sort((a, b) => a.type.compareTo(b.type));

    sharedWeaknesses.sort((a, b) => b.multiplier.compareTo(a.multiplier));
    uncoveredWeaknesses.sort((a, b) => b.multiplier.compareTo(a.multiplier));

    return TypeCoverageSummary(
      sharedWeaknesses: sharedWeaknesses,
      uncoveredWeaknesses: uncoveredWeaknesses,
      resistances: resistances,
      immunities: immunities,
    );
  }
}

void _arrangeCatalogDependencies(List<PokemonEntity> pokemon) {
  final cacheStore = _InMemoryPokemonCacheStore.fromPokemon(pokemon);
  appDependencies = AppDependencies(
    cacheStore: cacheStore,
    catalogService: PokemonCatalogService(cacheStore: cacheStore),
    snapshotRepository: DataSourceSnapshotRepository(
      store: _NoopSnapshotStore(),
      clock: const SystemClock(),
    ),
    csvLoader: const _StubCsvLoader(),
    typeMatchupService: const _FakeTypeMatchupService(),
    statCalculator: const PokemonStatCalculator(),
  );
}
