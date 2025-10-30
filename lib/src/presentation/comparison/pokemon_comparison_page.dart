import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../bootstrap.dart' show appDependencies;
import '../../data/models/pokemon_models.dart';
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

class PokemonComparisonPage extends StatefulWidget {
  const PokemonComparisonPage({super.key, required this.pokemonIds});

  final List<int> pokemonIds;

  @override
  State<PokemonComparisonPage> createState() => _PokemonComparisonPageState();
}

class _PokemonComparisonPageState extends State<PokemonComparisonPage> {
  late Future<List<PokemonEntity>> _pokemonFuture;
  ComparisonSort _sort = ComparisonSort.dex;

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
          if (data.isEmpty) {
            return const _ErrorView(
              message: 'No Pokemon available to compare.',
            );
          }
          final ordered = _orderByRequestedIds(data, widget.pokemonIds);
          return _ComparisonView(
            pokemon: ordered,
            sort: _sort,
            onSortChanged: (value) => setState(() => _sort = value),
          );
        },
      ),
    );
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
}

class _ComparisonView extends StatelessWidget {
  const _ComparisonView({
    required this.pokemon,
    required this.sort,
    required this.onSortChanged,
  });

  final List<PokemonEntity> pokemon;
  final ComparisonSort sort;
  final ValueChanged<ComparisonSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final sortedPokemon = _sortedPokemon(pokemon, sort);
    final totals = sortedPokemon.map(_baseStatTotal).toList(growable: false);
    final maxTotal = totals.isEmpty ? null : totals.reduce(math.max);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SegmentedButton<ComparisonSort>(
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
                label: Text('BST'),
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
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: sortedPokemon.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entity = sortedPokemon[index];
              final isBest = maxTotal != null && totals[index] == maxTotal;
              return _PokemonSummaryCard(
                pokemon: entity,
                baseStatTotal: totals[index],
                highlight: isBest,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _StatsComparisonBars(pokemon: sortedPokemon),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _StatsTable(pokemon: sortedPokemon),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<PokemonEntity> _sortedPokemon(
    List<PokemonEntity> source,
    ComparisonSort sort,
  ) {
    final copy = List<PokemonEntity>.from(source);
    switch (sort) {
      case ComparisonSort.dex:
        copy.sort((a, b) => a.id.compareTo(b.id));
        break;
      case ComparisonSort.name:
        copy.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case ComparisonSort.total:
        copy.sort((a, b) {
          final totalDiff = _baseStatTotal(b).compareTo(_baseStatTotal(a));
          if (totalDiff != 0) return totalDiff;
          return a.id.compareTo(b.id);
        });
        break;
    }
    return copy;
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.pokemon});

  final List<PokemonEntity> pokemon;

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
          .map((entity) => entity.defaultForm.baseStat(statId))
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

    final totals = pokemon.map(_baseStatTotal).toList(growable: false);
    final maxTotal = totals.isEmpty ? null : totals.reduce(math.max);
    rows.add(
      DataRow(
        cells: [
          const DataCell(Text('Total')),
          for (final total in totals)
            DataCell(
              Text(
                total.toString(),
                style: maxTotal != null && total == maxTotal
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
          theme.colorScheme.surfaceVariant.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _PokemonSummaryCard extends StatelessWidget {
  const _PokemonSummaryCard({
    required this.pokemon,
    required this.baseStatTotal,
    required this.highlight,
  });

  final PokemonEntity pokemon;
  final int baseStatTotal;
  final bool highlight;

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
                      backgroundColor:
                          theme.colorScheme.surfaceVariant.withOpacity(0.8),
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
                const SizedBox(height: 16),
                Text(
                  'Base stat total',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      baseStatTotal.toString(),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsComparisonBars extends StatelessWidget {
  const _StatsComparisonBars({required this.pokemon});

  final List<PokemonEntity> pokemon;

  @override
  Widget build(BuildContext context) {
    if (pokemon.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final statKeys = <String>[..._kStatOrder, 'total'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final showBars = constraints.maxWidth >= 420;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stat comparison', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < statKeys.length; i++) ...[
              _StatComparisonRow(
                statId: statKeys[i],
                pokemon: pokemon,
                showBars: showBars,
              ),
              if (i != statKeys.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatComparisonRow extends StatelessWidget {
  const _StatComparisonRow({
    required this.statId,
    required this.pokemon,
    required this.showBars,
  });

  final String statId;
  final List<PokemonEntity> pokemon;
  final bool showBars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = statId == 'total'
        ? 'Base stat total'
        : _kStatLabels[statId] ?? statId.toUpperCase();
    final values = <int?>[
      for (final entity in pokemon)
        statId == 'total'
            ? _baseStatTotal(entity)
            : entity.defaultForm.baseStat(statId),
    ];
    final numericValues = values.whereType<int>().toList(growable: false);
    final maxValue =
        numericValues.isEmpty ? 0 : numericValues.reduce(math.max);

    if (!showBars) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (var i = 0; i < pokemon.length; i++)
                Text(
                  '${_capitalize(pokemon[i].name)}: ${values[i]?.toString() ?? '-'}',
                  style: _textStyleForValue(
                    theme,
                    values[i],
                    maxValue,
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < pokemon.length; i++)
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: i == pokemon.length - 1 ? 0 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalize(pokemon[i].name),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _progressForValue(values[i], maxValue),
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.surfaceVariant
                                    .withOpacity(0.5),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _barColorForValue(
                                    theme,
                                    values[i],
                                    maxValue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            values[i]?.toString() ?? '-',
                            style: _textStyleForValue(
                              theme,
                              values[i],
                              maxValue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _progressForValue(int? value, int maxValue) {
    if (value == null || maxValue <= 0) {
      return 0;
    }
    final progress = value / maxValue;
    if (progress.isNaN || progress.isInfinite) {
      return 0;
    }
    return progress.clamp(0.0, 1.0);
  }

  TextStyle? _textStyleForValue(
    ThemeData theme,
    int? value,
    int maxValue,
  ) {
    final baseStyle = theme.textTheme.bodyMedium;
    if (value != null && maxValue > 0 && value == maxValue) {
      return baseStyle?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      );
    }
    return baseStyle;
  }

  Color _barColorForValue(
    ThemeData theme,
    int? value,
    int maxValue,
  ) {
    if (value != null && maxValue > 0 && value == maxValue) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.primary.withOpacity(0.45);
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

int _baseStatTotal(PokemonEntity pokemon) {
  return pokemon.defaultForm.stats.fold<int>(
    0,
    (total, stat) => total + stat.baseValue,
  );
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}
