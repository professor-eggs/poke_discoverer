import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../bootstrap.dart'
    show AppDependencies, appDependencies, initializeDependencies;
import '../../data/models/pokemon_models.dart';
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

enum ComparisonSort { dex, name, total }

enum StatDisplayMode { base, computed }

enum LevelControlMode { dragInput, buttonCluster }

const LevelControlMode kLevelControlMode = LevelControlMode.buttonCluster;

typedef InitializeDependenciesCallback = Future<AppDependencies> Function({
  bool forceImport,
});

@visibleForTesting
InitializeDependenciesCallback initializeComparisonDependencies =
    initializeDependencies;

@visibleForTesting
void resetInitializeComparisonDependencies() {
  initializeComparisonDependencies = initializeDependencies;
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
  StatDisplayMode _statMode = StatDisplayMode.base;
  final Map<int, int> _levels = <int, int>{};
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
            onSortChanged: (value) => setState(() => _sort = value),
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
      final refreshed =
          await initializeComparisonDependencies(forceImport: true);
      appDependencies = refreshed;
      _levels.clear();
      setState(() {
        _pokemonFuture =
            appDependencies.catalogService.getPokemonByIds(widget.pokemonIds);
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
    required this.onSortChanged,
    required this.statMode,
    required this.onStatModeChanged,
    required this.levels,
    required this.onLevelChanged,
    required this.missingIds,
    required this.isSeeding,
    required this.seedError,
    required this.onSeedRequested,
  });

  final List<PokemonEntity> pokemon;
  final ComparisonSort sort;
  final ValueChanged<ComparisonSort> onSortChanged;
  final StatDisplayMode statMode;
  final ValueChanged<StatDisplayMode> onStatModeChanged;
  final Map<int, int> levels;
  final void Function(int pokemonId, int level) onLevelChanged;
  final List<int> missingIds;
  final bool isSeeding;
  final String? seedError;
  final VoidCallback onSeedRequested;

  @override
  Widget build(BuildContext context) {
    final calculator = appDependencies.statCalculator;

    Map<String, int> baseStatsFor(PokemonEntity entity) =>
        _baseStatsFor(entity);

    Map<String, int> computedStatsFor(PokemonEntity entity) {
      final level = levels[entity.id] ?? 50;
      return calculator.computeStats(pokemon: entity, level: level);
    }

    int totalFor(PokemonEntity entity, StatDisplayMode mode) {
      final stats = mode == StatDisplayMode.base
          ? baseStatsFor(entity)
          : computedStatsFor(entity);
      return stats.values.fold<int>(0, (sum, value) => sum + value);
    }

    final sortedPokemon = List<PokemonEntity>.from(pokemon);
    switch (sort) {
      case ComparisonSort.dex:
        sortedPokemon.sort((a, b) => a.id.compareTo(b.id));
        break;
      case ComparisonSort.name:
        sortedPokemon.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case ComparisonSort.total:
        sortedPokemon.sort((a, b) {
          final diff = totalFor(b, statMode).compareTo(totalFor(a, statMode));
          if (diff != 0) return diff;
          return a.id.compareTo(b.id);
        });
        break;
    }

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

    final statsByPokemon = <int, Map<String, int>>{};
    final totalsByPokemon = <int, int>{};
    for (final entity in sortedPokemon) {
      final stats = statMode == StatDisplayMode.base
          ? baseStatsFor(entity)
          : computedStatsFor(entity);
      statsByPokemon[entity.id] = stats;
      totalsByPokemon[entity.id] = stats.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
    }

    final totals = sortedPokemon
        .map((entity) => totalsByPokemon[entity.id] ?? 0)
        .toList(growable: false);
    final maxTotal = totals.isEmpty ? null : totals.reduce(math.max);

    return ListView(
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
              SegmentedButton<ComparisonSort>(
                segments: const [
                  ButtonSegment(
                    value: ComparisonSort.dex,
                    label: Text('Dex'),
                    icon: Icon(Icons.numbers),
                  ),
                  ButtonSegment(
                    value: ComparisonSort.name,
                    label: Text('Name'),
                    icon: Icon(Icons.sort_by_alpha),
                  ),
                  ButtonSegment(
                    value: ComparisonSort.total,
                    label: Text('Total'),
                    icon: Icon(Icons.bar_chart),
                  ),
                ],
                selected: <ComparisonSort>{sort},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    onSortChanged(selection.first);
                  }
                },
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
            ],
          ),
        ),
        SizedBox(
          height: statMode == StatDisplayMode.computed ? 420 : 280,
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
              final statLabel = statMode == StatDisplayMode.base
                  ? 'Base stat total'
                  : 'Lv $level total';
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
        headingRowColor: MaterialStatePropertyAll(
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
  });

  final PokemonEntity pokemon;
  final int statTotal;
  final String statLabel;
  final bool highlight;
  final int level;
  final bool showLevelControls;
  final LevelControlMode mode;
  final ValueChanged<int> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultForm = pokemon.defaultForm;
    final accentColor = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return SizedBox(
      width: 220,
      child: Card(
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
          child: Padding(
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
                ],
              ],
            ),
          ),
        ),
      ),
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
        )
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
            Text(
              message,
              style: theme.textTheme.bodyMedium,
            ),
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
