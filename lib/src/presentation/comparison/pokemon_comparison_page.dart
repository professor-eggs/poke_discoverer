import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../bootstrap.dart'
    show AppDependencies, appDependencies, initializeDependencies;
import '../../data/models/pokemon_models.dart';
import '../../data/services/pokemon_stat_calculator.dart';
import '../../data/services/type_matchup_service.dart';
import '../detail/pokemon_detail_page.dart';
import '../widgets/sprite_avatar.dart';

const List<String> _kStatOrder = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
const Map<String, String> _kStatLabels = <String, String>{
  'hp': 'HP',
  'atk': 'Attack',
  'def': 'Defense',
  'spa': 'Sp. Attack',
  'spd': 'Sp. Defense',
  'spe': 'Speed',
};
const Map<ComparisonSort, String> _kSortLabels = <ComparisonSort, String>{
  ComparisonSort.dex: 'Dex number',
  ComparisonSort.name: 'Name',
  ComparisonSort.total: 'Stat total',
  ComparisonSort.hp: 'HP',
  ComparisonSort.atk: 'Attack',
  ComparisonSort.def: 'Defense',
  ComparisonSort.spa: 'Sp. Attack',
  ComparisonSort.spd: 'Sp. Defense',
  ComparisonSort.spe: 'Speed',
};

enum ComparisonSort { dex, name, total, hp, atk, def, spa, spd, spe }

enum StatDisplayMode { base, computed }

enum LevelControlMode { dragInput, buttonCluster }

const LevelControlMode kLevelControlMode = LevelControlMode.buttonCluster;

typedef InitializeDependenciesCallback =
    Future<AppDependencies> Function({bool forceImport});

@visibleForTesting
InitializeDependenciesCallback initializeComparisonDependencies =
    initializeDependencies;

@visibleForTesting
void resetInitializeComparisonDependencies() {
  initializeComparisonDependencies = initializeDependencies;
}

enum StatPreset {
  neutral,
  physicalSweeper,
  specialSweeper,
  physicalWall,
  specialWall
}

extension StatPresetData on StatPreset {
  String get label {
    switch (this) {
      case StatPreset.neutral:
        return 'Neutral';
      case StatPreset.physicalSweeper:
        return 'Physical sweeper';
      case StatPreset.specialSweeper:
        return 'Special sweeper';
      case StatPreset.physicalWall:
        return 'Physical wall';
      case StatPreset.specialWall:
        return 'Special wall';
    }
  }

  String get shortLabel {
    switch (this) {
      case StatPreset.neutral:
        return 'Neutral';
      case StatPreset.physicalSweeper:
        return 'Phys. Sweep';
      case StatPreset.specialSweeper:
        return 'Sp. Sweep';
      case StatPreset.physicalWall:
        return 'Phys. Wall';
      case StatPreset.specialWall:
        return 'Sp. Wall';
    }
  }

  String get description {
    switch (this) {
      case StatPreset.neutral:
        return 'No EV investment, neutral nature.';
      case StatPreset.physicalSweeper:
        return '+Atk / max Speed EVs, Adamant nature.';
      case StatPreset.specialSweeper:
        return '+Sp. Atk / max Speed EVs, Modest nature.';
      case StatPreset.physicalWall:
        return '+Def / max HP EVs, Impish nature.';
      case StatPreset.specialWall:
        return '+Sp. Def / max HP EVs, Careful nature.';
    }
  }

  StatCalculationProfile get profile {
    switch (this) {
      case StatPreset.neutral:
        return const StatCalculationProfile(individualValue: 31);
      case StatPreset.physicalSweeper:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'atk': 252, 'spe': 252, 'hp': 4},
          natureMultipliers: <String, double>{'atk': 1.1, 'spa': 0.9},
        );
      case StatPreset.specialSweeper:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'spa': 252, 'spe': 252, 'hp': 4},
          natureMultipliers: <String, double>{'spa': 1.1, 'atk': 0.9},
        );
      case StatPreset.physicalWall:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'hp': 252, 'def': 252, 'spd': 4},
          natureMultipliers: <String, double>{'def': 1.1, 'atk': 0.9},
        );
      case StatPreset.specialWall:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'hp': 252, 'spd': 252, 'def': 4},
          natureMultipliers: <String, double>{'spd': 1.1, 'atk': 0.9},
        );
    }
  }
}

String? _statKeyForSort(ComparisonSort sort) {
  switch (sort) {
    case ComparisonSort.hp:
      return 'hp';
    case ComparisonSort.atk:
      return 'atk';
    case ComparisonSort.def:
      return 'def';
    case ComparisonSort.spa:
      return 'spa';
    case ComparisonSort.spd:
      return 'spd';
    case ComparisonSort.spe:
      return 'spe';
    case ComparisonSort.dex:
    case ComparisonSort.name:
    case ComparisonSort.total:
      return null;
  }
}

class PokemonComparisonPage extends StatefulWidget {
  const PokemonComparisonPage({super.key, required this.pokemonIds});

  final List<int> pokemonIds;

  @override
  State<PokemonComparisonPage> createState() => _PokemonComparisonPageState();
}

class _PokemonComparisonPageState extends State<PokemonComparisonPage> {
  late Future<List<PokemonEntity>> _pokemonFuture;
  ComparisonSort _sort = ComparisonSort.dex;
  bool _sortAscending = true;
  StatDisplayMode _statMode = StatDisplayMode.base;
  final Map<int, int> _levels = <int, int>{};
  final Map<int, StatPreset> _presets = <int, StatPreset>{};
  bool _isSeeding = false;
  String? _seedError;

  @override
  void initState() {
    super.initState();
    _pokemonFuture = appDependencies.catalogService.getPokemonByIds(
      widget.pokemonIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Compare (${widget.pokemonIds.length})')),
      body: FutureBuilder<List<PokemonEntity>>(
        future: _pokemonFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(message: snapshot.error.toString());
          }
          final data = snapshot.data ?? const <PokemonEntity>[];
          final ordered = _orderByRequestedIds(data, widget.pokemonIds);
          final missingIds = _missingIdsFor(ordered);
          if (ordered.isEmpty && missingIds.isEmpty) {
            return const _ErrorView(
              message: 'No Pokemon available to compare.',
            );
          }
          _ensureLevels(ordered);
          return _ComparisonView(
            pokemon: ordered,
            sort: _sort,
            sortAscending: _sortAscending,
            onSortChanged: (value) => setState(() => _sort = value),
            onSortAscendingChanged: (ascending) {
              setState(() => _sortAscending = ascending);
            },
            statMode: _statMode,
            onStatModeChanged: (mode) {
              setState(() => _statMode = mode);
            },
            levels: _levels,
            onLevelChanged: (pokemonId, level) {
              setState(() {
                _levels[pokemonId] = level.clamp(1, 100);
              });
            },
            onApplyLevelToAll: (level) {
              setState(() {
                for (final entity in ordered) {
                  _levels[entity.id] = level.clamp(1, 100);
                }
              });
            },
            presets: _presets,
            onPresetChanged: (pokemonId, preset) {
              setState(() {
                _presets[pokemonId] = preset;
              });
            },
            missingIds: missingIds,
            isSeeding: _isSeeding,
            seedError: _seedError,
            onSeedRequested: _handleSeedRequest,
          );
        },
      ),
    );
  }

  void _ensureLevels(List<PokemonEntity> pokemon) {
    for (final entity in pokemon) {
      _levels.putIfAbsent(entity.id, () => 50);
      _presets.putIfAbsent(entity.id, () => StatPreset.neutral);
    }
  }

  List<PokemonEntity> _orderByRequestedIds(
    List<PokemonEntity> data,
    List<int> ids,
  ) {
    final map = <int, PokemonEntity>{
      for (final entity in data) entity.id: entity,
    };
    final ordered = <PokemonEntity>[];
    for (final id in ids) {
      final match = map[id];
      if (match != null) {
        ordered.add(match);
      }
    }
    for (final entity in data) {
      if (!ids.contains(entity.id)) {
        ordered.add(entity);
      }
    }
    return ordered;
  }

  List<int> _missingIdsFor(List<PokemonEntity> present) {
    final presentIds = present.map((entity) => entity.id).toSet();
    return widget.pokemonIds
        .where((id) => !presentIds.contains(id))
        .toList(growable: false);
  }

  Future<void> _handleSeedRequest() async {
    if (_isSeeding) return;
    setState(() {
      _isSeeding = true;
      _seedError = null;
    });
    try {
      final refreshed = await initializeComparisonDependencies(
        forceImport: true,
      );
      appDependencies = refreshed;
      _levels.clear();
      _presets.clear();
      setState(() {
        _pokemonFuture = appDependencies.catalogService.getPokemonByIds(
          widget.pokemonIds,
        );
      });
    } catch (error) {
      setState(() {
        _seedError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }
}

class _ComparisonView extends StatelessWidget {
  const _ComparisonView({
    required this.pokemon,
    required this.sort,
    required this.sortAscending,
    required this.onSortChanged,
    required this.onSortAscendingChanged,
    required this.statMode,
    required this.onStatModeChanged,
    required this.levels,
    required this.onLevelChanged,
    required this.onApplyLevelToAll,
    required this.presets,
    required this.onPresetChanged,
    required this.missingIds,
    required this.isSeeding,
    required this.seedError,
    required this.onSeedRequested,
  });

  final List<PokemonEntity> pokemon;
  final ComparisonSort sort;
  final bool sortAscending;
  final ValueChanged<ComparisonSort> onSortChanged;
  final ValueChanged<bool> onSortAscendingChanged;
  final StatDisplayMode statMode;
  final ValueChanged<StatDisplayMode> onStatModeChanged;
  final Map<int, int> levels;
  final void Function(int pokemonId, int level) onLevelChanged;
  final ValueChanged<int> onApplyLevelToAll;
  final Map<int, StatPreset> presets;
  final void Function(int pokemonId, StatPreset preset) onPresetChanged;
  final List<int> missingIds;
  final bool isSeeding;
  final String? seedError;
  final VoidCallback onSeedRequested;

  @override
  Widget build(BuildContext context) {
    final calculator = appDependencies.statCalculator;
    final statsByPokemon = <int, Map<String, int>>{};
    final totalsByPokemon = <int, int>{};

    Map<String, int> baseStatsFor(PokemonEntity entity) =>
        _baseStatsFor(entity);

    Map<String, int> computedStatsFor(PokemonEntity entity) {
      final level = levels[entity.id] ?? 50;
      final preset = presets[entity.id] ?? StatPreset.neutral;
      return calculator.computeStats(
        pokemon: entity,
        level: level,
        profile: preset.profile,
      );
    }

    for (final entity in pokemon) {
      final stats = statMode == StatDisplayMode.base
          ? baseStatsFor(entity)
          : computedStatsFor(entity);
      statsByPokemon[entity.id] = stats;
      totalsByPokemon[entity.id] =
          stats.values.fold<int>(0, (sum, value) => sum + value);
    }

    final sortedPokemon = List<PokemonEntity>.from(pokemon);
    final statSortKey = _statKeyForSort(sort);

    int compareBySort(PokemonEntity a, PokemonEntity b) {
      if (statSortKey != null) {
        final aValue = statsByPokemon[a.id]?[statSortKey] ?? 0;
        final bValue = statsByPokemon[b.id]?[statSortKey] ?? 0;
        return aValue.compareTo(bValue);
      }
      switch (sort) {
        case ComparisonSort.dex:
          return a.id.compareTo(b.id);
        case ComparisonSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ComparisonSort.total:
          final aTotal = totalsByPokemon[a.id] ?? 0;
          final bTotal = totalsByPokemon[b.id] ?? 0;
          return aTotal.compareTo(bTotal);
        case ComparisonSort.hp:
        case ComparisonSort.atk:
        case ComparisonSort.def:
        case ComparisonSort.spa:
        case ComparisonSort.spd:
        case ComparisonSort.spe:
          // Covered by statSortKey branch.
          return 0;
      }
    }

    final direction = sortAscending ? 1 : -1;
    sortedPokemon.sort((a, b) {
      final result = compareBySort(a, b) * direction;
      if (result != 0) {
        return result;
      }
      return a.id.compareTo(b.id);
    });

    if (sortedPokemon.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          if (missingIds.isNotEmpty)
            _MissingDataBanner(
              missingIds: missingIds,
              isSeeding: isSeeding,
              seedError: seedError,
              onSeedRequested: onSeedRequested,
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Import the cached Pokemon data to compare these Pokemon offline.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      );
    }

    int? sharedLevel;
    if (sortedPokemon.isNotEmpty) {
      final baseline = levels[sortedPokemon.first.id] ?? 50;
      final allSame = sortedPokemon.every(
        (entity) => (levels[entity.id] ?? 50) == baseline,
      );
      if (allSame) {
        sharedLevel = baseline;
      }
    }

    final totals = sortedPokemon
        .map((entity) => totalsByPokemon[entity.id] ?? 0)
        .toList(growable: false);
    final maxTotal = totals.isEmpty ? null : totals.reduce(math.max);

    return ListView(
      key: const Key('comparisonScroll'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (missingIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _MissingDataBanner(
              missingIds: missingIds,
              isSeeding: isSeeding,
              seedError: seedError,
              onSeedRequested: onSeedRequested,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ComparisonSort>(
                      key: const Key('comparisonSortDropdown'),
                      value: sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ComparisonSort.values
                          .map(
                            (value) => DropdownMenuItem<ComparisonSort>(
                              value: value,
                              child: Text(
                                _kSortLabels[value] ?? value.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          onSortChanged(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: sortAscending ? 'Ascending' : 'Descending',
                    child: IconButton.filledTonal(
                      key: const Key('comparisonSortDirection'),
                      onPressed: () =>
                          onSortAscendingChanged(!sortAscending),
                      icon: Icon(
                        sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<StatDisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: StatDisplayMode.base,
                    label: Text('Base'),
                  ),
                  ButtonSegment(
                    value: StatDisplayMode.computed,
                    label: Text('Computed'),
                  ),
                ],
                selected: <StatDisplayMode>{statMode},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    onStatModeChanged(selection.first);
                  }
                },
              ),
              if (statMode == StatDisplayMode.computed) ...[
                const SizedBox(height: 16),
                _GlobalLevelControl(
                  sharedLevel: sharedLevel,
                  onApply: onApplyLevelToAll,
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: statMode == StatDisplayMode.computed ? 520 : 420,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: sortedPokemon.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entity = sortedPokemon[index];
              final total = totalsByPokemon[entity.id] ?? 0;
              final isBest = maxTotal != null && total == maxTotal;
              final level = levels[entity.id] ?? 50;
              final preset = presets[entity.id] ?? StatPreset.neutral;
              final statLabel = statMode == StatDisplayMode.base
                  ? 'Base stat total'
                  : 'Lv $level total (${preset.shortLabel})';
              return _PokemonSummaryCard(
                pokemon: entity,
                statTotal: total,
                statLabel: statLabel,
                highlight: isBest,
                level: level,
                showLevelControls: statMode == StatDisplayMode.computed,
                mode: kLevelControlMode,
                onLevelChanged: (newLevel) =>
                    onLevelChanged(entity.id, newLevel),
                preset: preset,
                onPresetChanged: (newPreset) =>
                    onPresetChanged(entity.id, newPreset),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _StatsTable(
                pokemon: sortedPokemon,
                statMode: statMode,
                levels: levels,
                statsByPokemon: statsByPokemon,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TeamCoverageCard(pokemon: sortedPokemon),
        ),
      ],
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({
    required this.pokemon,
    required this.statMode,
    required this.levels,
    required this.statsByPokemon,
  });

  final List<PokemonEntity> pokemon;
  final StatDisplayMode statMode;
  final Map<int, int> levels;
  final Map<int, Map<String, int>> statsByPokemon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = <DataColumn>[
      const DataColumn(label: Text('Stat')),
      for (final entity in pokemon)
        DataColumn(
          label: Text(
            _capitalize(entity.name),
            style: theme.textTheme.bodyMedium,
          ),
        ),
    ];

    final rows = <DataRow>[];
    for (final statId in _kStatOrder) {
      final values = pokemon
          .map((entity) => statsByPokemon[entity.id]?[statId])
          .toList(growable: false);
      int? maxValue;
      for (final value in values) {
        if (value == null) continue;
        maxValue = maxValue == null ? value : math.max(maxValue, value);
      }
      final label = _kStatLabels[statId] ?? statId.toUpperCase();
      rows.add(
        DataRow(
          cells: [
            DataCell(Text(label)),
            for (final value in values)
              DataCell(
                Text(
                  value?.toString() ?? '—',
                  style: value != null && maxValue != null && value == maxValue
                      ? theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        )
                      : theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      );
    }

    final totals = pokemon
        .map(
          (entity) => statsByPokemon[entity.id]!.values.fold<int>(
            0,
            (sum, value) => sum + value,
          ),
        )
        .toList(growable: false);
    final maxTotal = totals.isEmpty ? null : totals.reduce(math.max);
    rows.add(
      DataRow(
        cells: [
          DataCell(
            Text(statMode == StatDisplayMode.base ? 'Total' : 'Total (Lv)'),
          ),
          for (var i = 0; i < totals.length; i++)
            DataCell(
              Text(
                statMode == StatDisplayMode.base
                    ? totals[i].toString()
                    : '${totals[i]} (Lv ${levels[pokemon[i].id] ?? 50})',
                style: maxTotal != null && totals[i] == maxTotal
                    ? theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      )
                    : theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        columnSpacing: 32,
        headingRowHeight: 48,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        headingRowColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _PokemonSummaryCard extends StatelessWidget {
  const _PokemonSummaryCard({
    required this.pokemon,
    required this.statTotal,
    required this.statLabel,
    required this.highlight,
    required this.level,
    required this.showLevelControls,
    required this.mode,
    required this.onLevelChanged,
    required this.preset,
    required this.onPresetChanged,
  });

  final PokemonEntity pokemon;
  final int statTotal;
  final String statLabel;
  final bool highlight;
  final int level;
  final bool showLevelControls;
  final LevelControlMode mode;
  final ValueChanged<int> onLevelChanged;
  final StatPreset preset;
  final ValueChanged<StatPreset> onPresetChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultForm = pokemon.defaultForm;
    final accentColor = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final recommendedMoves = _recommendMoves(
      form: defaultForm,
      preset: preset,
      level: level,
    );

    return SizedBox(
      width: 220,
      child: Card(
        key: ValueKey('comparison-card-${pokemon.id}'),
        clipBehavior: Clip.antiAlias,
        elevation: highlight ? 6 : 2,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PokemonDetailPage(pokemonId: pokemon.id),
              ),
            );
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SpriteAvatar(
                      pokemon: pokemon,
                      size: 56,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${pokemon.id.toString().padLeft(3, '0')}',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _capitalize(pokemon.name),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: accentColor,
                              fontWeight: highlight ? FontWeight.w600 : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            defaultForm.types
                                .map((type) => _capitalize(type))
                                .join(' / '),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(statLabel, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      statTotal.toString(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: accentColor,
                        fontWeight: highlight ? FontWeight.w600 : null,
                      ),
                    ),
                    if (highlight) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.emoji_events,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                if (showLevelControls) ...[
                  const SizedBox(height: 8),
                  _LevelControl(
                    mode: mode,
                    level: level,
                    onLevelChanged: onLevelChanged,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Battle role',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<StatPreset>(
                    key: ValueKey('presetDropdown-${pokemon.id}'),
                    value: preset,
                    isExpanded: true,
                    items: StatPreset.values
                        .map(
                          (option) => DropdownMenuItem<StatPreset>(
                            value: option,
                            child: Text(option.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        onPresetChanged(value);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (recommendedMoves.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recommended moves',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  _RecommendedMovesList(moves: recommendedMoves),
                ],
if (defaultForm.types.isNotEmpty) ...[
  const SizedBox(height: 12),
  _TypeMatchupPreview(types: defaultForm.types),
],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendedMovesList extends StatelessWidget {
  const _RecommendedMovesList({required this.moves});

  final List<_RecommendedMove> moves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final move in moves)
          Padding(
            padding: EdgeInsets.only(
              bottom: move == moves.last ? 0 : 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatMoveLabel(move.move.name),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: move.isStab || move.matchesPreset
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: move.isStab
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (move.tags.isNotEmpty)
                  Text(
                    move.tags.join(' • '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecommendedMove {
  const _RecommendedMove({
    required this.move,
    required this.tags,
    required this.score,
    required this.isStab,
    required this.matchesPreset,
  });

  final PokemonMoveSummary move;
  final List<String> tags;
  final int score;
  final bool isStab;
  final bool matchesPreset;
}

List<_RecommendedMove> _recommendMoves({
  required PokemonFormEntity form,
  required StatPreset preset,
  required int level,
}) {
  if (form.moves.isEmpty) {
    return const <_RecommendedMove>[];
  }
  final types = form.types.map((type) => type.toLowerCase()).toSet();
  final preferredDamageClass = _preferredDamageClassForPreset(preset);
  final results = <_RecommendedMove>[];
  for (final move in form.moves) {
    if (!_isMoveAvailable(move, level)) {
      continue;
    }
    final damageClass = move.damageClass.toLowerCase();
    final isStab = types.contains(move.type.toLowerCase());
    final matchesPreset = preferredDamageClass == null
        ? (preset == StatPreset.physicalWall ||
            preset == StatPreset.specialWall) &&
            damageClass == 'status'
        : damageClass == preferredDamageClass;

    var score = 0;
    if (isStab) {
      score += 40;
    }
    if (matchesPreset) {
      score += 60;
    }
    if (damageClass == 'status' &&
        (preset == StatPreset.physicalWall ||
            preset == StatPreset.specialWall)) {
      score += 50;
    }

    final power = move.power ?? 0;
    if (power > 0) {
      score += power;
    } else if (damageClass == 'status') {
      score += 20;
    }

    if (move.accuracy != null && move.accuracy! >= 95) {
      score += 5;
    }
    switch (move.methodId) {
      case 'machine':
        score += 10;
        break;
      case 'tutor':
        score += 8;
        break;
      case 'egg':
        score += 4;
        break;
      case 'level-up':
        score += 6;
        break;
    }

    if (preferredDamageClass != null && damageClass != preferredDamageClass) {
      score -= 30;
    }

    score += _keywordBonus(move.name, preset);

    if (score <= 0) {
      continue;
    }

    final tags = _buildMoveTags(
      move: move,
      isStab: isStab,
    );

    results.add(
      _RecommendedMove(
        move: move,
        tags: tags,
        score: score,
        isStab: isStab,
        matchesPreset: matchesPreset,
      ),
    );
  }

  results.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.move.name.compareTo(b.move.name);
  });

  return results.take(3).toList(growable: false);
}

String? _preferredDamageClassForPreset(StatPreset preset) {
  switch (preset) {
    case StatPreset.physicalSweeper:
      return 'physical';
    case StatPreset.specialSweeper:
      return 'special';
    case StatPreset.physicalWall:
    case StatPreset.specialWall:
      return 'status';
    case StatPreset.neutral:
      return null;
  }
}

bool _isMoveAvailable(PokemonMoveSummary move, int targetLevel) {
  if (move.methodId == 'level-up' && move.level != null && move.level! > 0) {
    return move.level! <= targetLevel;
  }
  return true;
}

List<String> _buildMoveTags({
  required PokemonMoveSummary move,
  required bool isStab,
}) {
  final tags = <String>[];
  if (isStab) {
    tags.add('STAB');
  }
  final damageLabel = _formatDamageClass(move.damageClass);
  if (damageLabel != null) {
    tags.add(damageLabel);
  }
  if (move.power != null && move.power! > 0) {
    tags.add('${move.power} BP');
  } else if (move.damageClass.toLowerCase() == 'status') {
    tags.add('Status');
  }
  if (move.methodId == 'level-up') {
    final requiredLevel = move.level;
    if (requiredLevel != null && requiredLevel > 0) {
      tags.add('Lv $requiredLevel');
    }
  } else {
    tags.add(move.method);
  }
  return tags;
}

String? _formatDamageClass(String damageClass) {
  switch (damageClass.toLowerCase()) {
    case 'physical':
      return 'Physical';
    case 'special':
      return 'Special';
    case 'status':
      return null;
    default:
      return null;
  }
}

String _formatMoveLabel(String rawName) {
  final parts = rawName
      .toLowerCase()
      .split(RegExp(r'[- ]'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part[0].toUpperCase() + part.substring(1),
      )
      .toList(growable: false);
  return parts.isEmpty ? rawName : parts.join(' ');
}

int _keywordBonus(String moveName, StatPreset preset) {
  final slug = moveName.toLowerCase().replaceAll(' ', '-');
  final bonus = _moveKeywordBonuses[slug] ?? 0;
  if (bonus == 0) {
    return 0;
  }
  if (preset == StatPreset.neutral) {
    return (bonus / 2).round();
  }
  return bonus;
}

const Map<String, int> _moveKeywordBonuses = <String, int>{
  'swords-dance': 30,
  'dragon-dance': 28,
  'bulk-up': 28,
  'calm-mind': 28,
  'nasty-plot': 32,
  'shell-smash': 35,
  'agility': 18,
  'rock-polish': 18,
  'quiver-dance': 32,
  'iron-defense': 26,
  'acid-armor': 26,
  'barrier': 24,
  'protect': 16,
  'detect': 16,
  'reflect': 24,
  'light-screen': 24,
  'recover': 34,
  'roost': 34,
  'soft-boiled': 34,
  'synthesis': 28,
  'moonlight': 28,
  'rest': 20,
  'leech-seed': 22,
  'will-o-wisp': 20,
  'toxic': 18,
  'stealth-rock': 26,
  'spikes': 24,
  'toxic-spikes': 24,
  'sticky-web': 24,
  'substitute': 20,
};

class _TypeMatchupPreview extends StatelessWidget {
  const _TypeMatchupPreview({required this.types});

  final List<String> types;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return FutureBuilder<TypeMatchupSummary>(
      future: appDependencies.typeMatchupService.defensiveSummary(types),
      builder: (context, snapshot) {
        final connection = snapshot.connectionState;
        if (connection == ConnectionState.waiting ||
            connection == ConnectionState.active) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Type coverage unavailable.',
            style: theme.textTheme.bodySmall,
          );
        }
        final summary =
            snapshot.data ??
            const TypeMatchupSummary(
              weaknesses: <TypeEffectivenessEntry>[],
              resistances: <TypeEffectivenessEntry>[],
              immunities: <TypeEffectivenessEntry>[],
            );
        if (summary.isEmpty) {
          return Text(
            'Type coverage unavailable.',
            style: theme.textTheme.bodySmall,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.weaknesses.isNotEmpty)
              _MatchupRow(label: 'Weak to', entries: summary.weaknesses),
            if (summary.resistances.isNotEmpty)
              _MatchupRow(label: 'Resists', entries: summary.resistances),
            if (summary.immunities.isNotEmpty)
              _MatchupRow(label: 'Immune to', entries: summary.immunities),
          ],
        );
      },
    );
  }
}

class _MatchupRow extends StatelessWidget {
  const _MatchupRow({required this.label, required this.entries});

  final String label;
  final List<TypeEffectivenessEntry> entries;

  static const int _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = entries.take(_maxVisible).toList(growable: false);
    final overflow = entries.length - visible.length;

    final items = visible
        .map(
          (entry) =>
              '${_capitalize(entry.type)} ${_formatMultiplier(entry.multiplier)}',
        )
        .join(', ');
    final overflowLabel = overflow > 0 ? ' (+$overflow more)' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label $items$overflowLabel',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _GlobalLevelControl extends StatefulWidget {
  const _GlobalLevelControl({
    required this.sharedLevel,
    required this.onApply,
  });

  final int? sharedLevel;
  final ValueChanged<int> onApply;

  @override
  State<_GlobalLevelControl> createState() => _GlobalLevelControlState();
}

class _GlobalLevelControlState extends State<_GlobalLevelControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _syncText();
  }

  @override
  void didUpdateWidget(covariant _GlobalLevelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedLevel != widget.sharedLevel) {
      _syncText();
    }
  }

  void _syncText() {
    final value = widget.sharedLevel;
    _controller.text = value?.toString() ?? '';
  }

  void _applyLevel(int level) {
    final clamped = level.clamp(1, 100);
    _controller.text = clamped.toString();
    widget.onApply(clamped);
  }

  void _handleSubmit(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      _syncText();
      return;
    }
    _applyLevel(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sharedLevel = widget.sharedLevel;
    final status = sharedLevel == null
        ? 'Levels vary across Pokemon.'
        : 'All cards using level $sharedLevel.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set level for all compared Pokemon',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: TextField(
                key: const Key('comparisonGlobalLevelField'),
                controller: _controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: _handleSubmit,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Level',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetLevelButton(
                    key: const Key('comparisonGlobalPreset50'),
                    label: '50',
                    onPressed: () => _applyLevel(50),
                  ),
                  _PresetLevelButton(
                    key: const Key('comparisonGlobalPreset100'),
                    label: '100',
                    onPressed: () => _applyLevel(100),
                  ),
                  _PresetLevelButton(
                    key: const Key('comparisonGlobalPreset75'),
                    label: '75',
                    onPressed: () => _applyLevel(75),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PresetLevelButton extends StatelessWidget {
  const _PresetLevelButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text('Lv $label'),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _LevelControl extends StatefulWidget {
  const _LevelControl({
    required this.mode,
    required this.level,
    required this.onLevelChanged,
  });

  final LevelControlMode mode;
  final int level;
  final ValueChanged<int> onLevelChanged;

  @override
  State<_LevelControl> createState() => _LevelControlState();
}

class _LevelControlState extends State<_LevelControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.level.toString());
  }

  @override
  void didUpdateWidget(covariant _LevelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.level != oldWidget.level) {
      final value = widget.level.toString();
      if (_controller.text != value) {
        _controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyLevel(int level) {
    final clamped = level.clamp(1, 100);
    if (clamped != widget.level) {
      widget.onLevelChanged(clamped);
    } else if (_controller.text != clamped.toString()) {
      _controller.text = clamped.toString();
    }
  }

  Widget _buildDragInput(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onPanUpdate: (details) {
        final delta = (-details.delta.dy / 4).round();
        if (delta != 0) {
          _applyLevel(widget.level + delta);
        }
      },
      child: SizedBox(
        width: 160,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Level',
            helperText: 'Drag up / down',
            helperStyle: theme.textTheme.bodySmall,
            isDense: true,
          ),
          onSubmitted: _handleText,
          onTapOutside: (_) => _handleText(_controller.text),
        ),
      ),
    );
  }

  Widget _buildButtonCluster(BuildContext context) {
    final theme = Theme.of(context);
    const pairs = <List<int>>[
      [-1, 1],
      [-5, 5],
      [-10, 10],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Level ${widget.level}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final pair in pairs) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IncrementButton(
                    label: pair[0].toString(),
                    onPressed: () => _applyLevel(widget.level + pair[0]),
                  ),
                  const SizedBox(width: 12),
                  _IncrementButton(
                    label: '+${pair[1]}',
                    onPressed: () => _applyLevel(widget.level + pair[1]),
                  ),
                ],
              ),
              if (pair != pairs.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ],
    );
  }

  void _handleText(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      _applyLevel(parsed);
    } else {
      _controller.text = widget.level.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.mode) {
      case LevelControlMode.dragInput:
        return _buildDragInput(context);
      case LevelControlMode.buttonCluster:
        return _buildButtonCluster(context);
    }
  }
}

class _IncrementButton extends StatelessWidget {
  const _IncrementButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(44, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _MissingDataBanner extends StatelessWidget {
  const _MissingDataBanner({
    required this.missingIds,
    required this.isSeeding,
    required this.seedError,
    required this.onSeedRequested,
  });

  final List<int> missingIds;
  final bool isSeeding;
  final String? seedError;
  final VoidCallback onSeedRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = missingIds.length;
    final formattedIds = missingIds
        .map((id) => '#${id.toString().padLeft(3, '0')}')
        .join(', ');
    final message = count == 1
        ? '$formattedIds is missing from the local cache.'
        : '$count Pokemon are missing from the local cache: $formattedIds.';

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: isSeeding ? null : onSeedRequested,
                  icon: isSeeding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(isSeeding ? 'Seeding…' : 'Import cached data'),
                ),
                const SizedBox(width: 12),
                if (seedError != null)
                  Expanded(
                    child: Text(
                      'Failed: $seedError',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCoverageCard extends StatelessWidget {
  const _TeamCoverageCard({required this.pokemon});

  final List<PokemonEntity> pokemon;

  @override
  Widget build(BuildContext context) {
    if (pokemon.isEmpty) {
      return const SizedBox.shrink();
    }

    final future = appDependencies.typeMatchupService.teamCoverage(
      pokemon.map((entity) => entity.defaultForm.types).toList(growable: false),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<TypeCoverageSummary>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final theme = Theme.of(context);
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Team coverage', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to compute coverage: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            }

            final summary =
                snapshot.data ??
                const TypeCoverageSummary(
                  sharedWeaknesses: <TypeEffectivenessEntry>[],
                  uncoveredWeaknesses: <TypeEffectivenessEntry>[],
                  resistances: <TypeEffectivenessEntry>[],
                  immunities: <TypeEffectivenessEntry>[],
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Team coverage', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (summary.isEmpty)
                  Text(
                    'Coverage summary unavailable.',
                    style: theme.textTheme.bodyMedium,
                  )
                else ...[
                  if (summary.sharedWeaknesses.isNotEmpty)
                    _CoverageGroup(
                      title: 'Shared weaknesses',
                      entries: summary.sharedWeaknesses,
                      chipColor: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    ),
                  if (summary.uncoveredWeaknesses.isNotEmpty)
                    _CoverageGroup(
                      title: 'Needs coverage',
                      entries: summary.uncoveredWeaknesses,
                      chipColor: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                  if (summary.resistances.isNotEmpty)
                    _CoverageGroup(
                      title: 'Covered by team',
                      entries: summary.resistances,
                      chipColor: theme.colorScheme.primaryContainer,
                      textColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  if (summary.immunities.isNotEmpty)
                    _CoverageGroup(
                      title: 'Team immunities',
                      entries: summary.immunities,
                      chipColor: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoverageGroup extends StatelessWidget {
  const _CoverageGroup({
    required this.title,
    required this.entries,
    required this.chipColor,
    required this.textColor,
  });

  final String title;
  final List<TypeEffectivenessEntry> entries;
  final Color chipColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries)
                Chip(
                  backgroundColor: chipColor,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: textColor,
                  ),
                  label: Text(
                    '${_capitalize(entry.type)} ${_formatMultiplier(entry.multiplier)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Map<String, int> _baseStatsFor(PokemonEntity pokemon) {
  final map = <String, int>{};
  for (final stat in pokemon.defaultForm.stats) {
    map[stat.statId] = stat.baseValue;
  }
  return map;
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

String _formatMultiplier(double multiplier) {
  if (multiplier == 0) {
    return 'x0';
  }
  if (multiplier % 1 == 0) {
    return 'x${multiplier.toInt()}';
  }
  return 'x${multiplier.toStringAsFixed(multiplier == 0.25 ? 2 : 1)}';
}
