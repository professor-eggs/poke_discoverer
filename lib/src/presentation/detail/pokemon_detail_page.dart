import 'package:flutter/material.dart';

import '../../bootstrap.dart' show appDependencies;
import '../../data/models/pokemon_models.dart';
import '../../data/services/type_matchup_service.dart';

class PokemonDetailPage extends StatefulWidget {
  const PokemonDetailPage({required this.pokemonId, super.key});

  final int pokemonId;

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  late Future<PokemonEntity?> _pokemonFuture;

  @override
  void initState() {
    super.initState();
    _pokemonFuture = appDependencies.catalogService.getPokemonById(
      widget.pokemonId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pokemon #${widget.pokemonId.toString().padLeft(3, '0')}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Stats'),
              Tab(text: 'Moves'),
            ],
          ),
        ),
        body: FutureBuilder<PokemonEntity?>(
          future: _pokemonFuture,
          builder: (context, snapshot) {
            Widget buildPlaceholder(Widget child) => TabBarView(
                  children: [
                    child,
                    child,
                  ],
                );
            if (snapshot.connectionState == ConnectionState.waiting) {
              return buildPlaceholder(
                const Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return buildPlaceholder(
                _ErrorView(message: snapshot.error.toString()),
              );
            }
            final pokemon = snapshot.data;
            if (pokemon == null) {
              return buildPlaceholder(
                const _ErrorView(
                  message: 'Pokemon not found in local cache.',
                ),
              );
            }
            return TabBarView(
              children: [
                _PokemonStatsView(pokemon: pokemon),
                _PokemonMovesView(pokemon: pokemon),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PokemonStatsView extends StatelessWidget {
  const _PokemonStatsView({required this.pokemon});

  final PokemonEntity pokemon;

  @override
  Widget build(BuildContext context) {
    final defaultForm = pokemon.defaultForm;
    final baseStatTotal = defaultForm.stats.fold<int>(
      0,
      (total, stat) => total + stat.baseValue,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _capitalize(pokemon.name),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: defaultForm.types
                .map(
                  (type) => Chip(
                    label: Text(_capitalize(type)),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'Base stat total', value: baseStatTotal.toString()),
          const SizedBox(height: 16),
          Text('Base stats', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: defaultForm.stats
                  .map(
                    (stat) => _StatRow(
                      statId: stat.statId,
                      baseValue: stat.baseValue,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          _TypeMatchupSection(types: defaultForm.types),
        ],
      ),
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.statId, required this.baseValue});

  final String statId;
  final int baseValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _formatStatLabel(statId);
    final normalized =
        (baseValue.clamp(0, 255)).toDouble() / 255.0; // 0 - 255 baseline

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showBar = constraints.maxWidth >= 360;
          final header = Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(baseValue.toString(), style: theme.textTheme.titleMedium),
            ],
          );
          if (!showBar) {
            return header;
          }
          final progress = normalized.clamp(0.0, 1.0);
          final background = theme.colorScheme.surfaceContainerHighest
              .withOpacity(0.6);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatStatLabel(String raw) {
    switch (raw) {
      case 'hp':
        return 'HP';
      case 'atk':
        return 'Attack';
      case 'def':
        return 'Defense';
      case 'spa':
        return 'Sp. Attack';
      case 'spd':
        return 'Sp. Defense';
      case 'spe':
        return 'Speed';
      default:
        return raw;
    }
  }
}

class _TypeMatchupSection extends StatelessWidget {
  const _TypeMatchupSection({required this.types});

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
        Widget content;
        if (snapshot.connectionState == ConnectionState.waiting) {
          content = const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          content = Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Failed to load type matchups.',
              style: theme.textTheme.bodyMedium,
            ),
          );
        } else {
          final summary =
              snapshot.data ??
              const TypeMatchupSummary(
                weaknesses: <TypeEffectivenessEntry>[],
                resistances: <TypeEffectivenessEntry>[],
                immunities: <TypeEffectivenessEntry>[],
              );
          if (summary.isEmpty) {
            content = Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Type matchups unavailable.',
                style: theme.textTheme.bodyMedium,
              ),
            );
          } else {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.weaknesses.isNotEmpty)
                  _EffectivenessGroup(
                    title: 'Weak to',
                    entries: summary.weaknesses,
                  ),
                if (summary.resistances.isNotEmpty)
                  _EffectivenessGroup(
                    title: 'Resists',
                    entries: summary.resistances,
                  ),
                if (summary.immunities.isNotEmpty)
                  _EffectivenessGroup(
                    title: 'Immune to',
                    entries: summary.immunities,
                  ),
              ],
            );
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type matchups', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                content,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EffectivenessGroup extends StatelessWidget {
  const _EffectivenessGroup({required this.title, required this.entries});

  final String title;
  final List<TypeEffectivenessEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

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
            children: entries
                .map(
                  (entry) => Chip(
                    label: Text(
                      '${_capitalize(entry.type)} x${_formatMultiplier(entry.multiplier)}',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String _formatMultiplier(double multiplier) {
    if (multiplier % 1 == 0) {
      return multiplier.toInt().toString();
    }
    if (multiplier == 0.25) {
      return '0.25';
    }
    if (multiplier == 0.5) {
      return '0.5';
    }
    return multiplier.toStringAsFixed(2);
  }
}

class _PokemonMovesView extends StatefulWidget {
  const _PokemonMovesView({required this.pokemon});

  final PokemonEntity pokemon;

  @override
  State<_PokemonMovesView> createState() => _PokemonMovesViewState();
}

class _PokemonMovesViewState extends State<_PokemonMovesView> {
  static const String _allMethodsId = '__all__';
  late final List<PokemonMoveSummary> _allMoves;
  late final List<_VersionOption> _versionOptions;
  String _activeMethodId = _allMethodsId;
  int? _selectedVersionGroupId;

  @override
  void initState() {
    super.initState();
    _allMoves = widget.pokemon.defaultForm.moves;
    _versionOptions = _buildVersionOptions(_allMoves);
    final initialGroups = _groupMoves(_allMoves);
    if (initialGroups.any((group) => group.id == 'level-up')) {
      _activeMethodId = 'level-up';
    }
    _selectedVersionGroupId = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredMoves = _filterMoves(_selectedVersionGroupId);
    final groups = _groupMoves(filteredMoves);
    final availableMethodIds = groups.map((group) => group.id).toSet();
    final effectiveMethodId = (_activeMethodId != _allMethodsId &&
            !availableMethodIds.contains(_activeMethodId))
        ? _allMethodsId
        : _activeMethodId;

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No moves found for this combination. Try adjusting the method or version filters.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final versionChips = <Widget>[
      ChoiceChip(
        label: const Text('All versions'),
        selected: _selectedVersionGroupId == null,
        onSelected: (_) {
          setState(() {
            _selectedVersionGroupId = null;
          });
        },
      ),
      for (final option in _versionOptions)
        ChoiceChip(
          label: Text(option.name),
          selected: _selectedVersionGroupId == option.id,
          onSelected: (_) {
            setState(() {
              _selectedVersionGroupId = option.id;
            });
          },
        ),
    ];

    final methodChips = <Widget>[
      ChoiceChip(
        label: const Text('All methods'),
        selected: effectiveMethodId == _allMethodsId,
        onSelected: (_) {
          setState(() {
            _activeMethodId = _allMethodsId;
          });
        },
      ),
      for (final group in groups)
        ChoiceChip(
          label: Text(group.name),
          selected: effectiveMethodId == group.id,
          onSelected: (_) {
            setState(() {
              _activeMethodId = group.id;
            });
          },
        ),
    ];

    final filteredGroups = effectiveMethodId == _allMethodsId
        ? groups
        : groups.where((group) => group.id == effectiveMethodId).toList();
    final displayGroups =
        filteredGroups.isEmpty ? groups : filteredGroups;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_versionOptions.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final chip in versionChips) ...[
                    chip,
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final chip in methodChips) ...[
                  chip,
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: displayGroups.length,
              itemBuilder: (context, index) {
                final group = displayGroups[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == displayGroups.length - 1 ? 0 : 16,
                  ),
                  child: _MoveGroupCard(
                    group: group,
                    selectedVersionGroupId: _selectedVersionGroupId,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<PokemonMoveSummary> _filterMoves(int? versionGroupId) {
    if (versionGroupId == null) {
      return _allMoves;
    }
    return _allMoves
        .where(
          (move) => move.versionDetails
              .any((detail) => detail.versionGroupId == versionGroupId),
        )
        .toList(growable: false);
  }

  List<_VersionOption> _buildVersionOptions(List<PokemonMoveSummary> moves) {
    final options = <int, _VersionOption>{};
    for (final move in moves) {
      for (final detail in move.versionDetails) {
        final existing = options[detail.versionGroupId];
        if (existing == null ||
            detail.sortOrder < existing.sortOrder ||
            (detail.sortOrder == existing.sortOrder &&
                detail.versionGroupName.compareTo(existing.name) < 0)) {
          options[detail.versionGroupId] = _VersionOption(
            id: detail.versionGroupId,
            name: detail.versionGroupName,
            sortOrder: detail.sortOrder,
          );
        }
      }
    }
    final list = options.values.toList(growable: false)
      ..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  List<_MethodGroup> _groupMoves(List<PokemonMoveSummary> moves) {
    int methodRank(String methodId) {
      switch (methodId) {
        case 'level-up':
          return 0;
        case 'machine':
          return 1;
        case 'tutor':
          return 2;
        case 'egg':
          return 3;
        default:
          return 4;
      }
    }

    String normalise(String value) => value.toLowerCase().trim();

    final Map<String, List<PokemonMoveSummary>> grouped = {};
    for (final move in moves) {
      final id = normalise(move.methodId);
      grouped.putIfAbsent(id, () => <PokemonMoveSummary>[]).add(move);
    }

    final groups = grouped.entries.map((entry) {
      final id = entry.key;
      final name = _titleCase(entry.value.first.method);
      final sortedMoves = List<PokemonMoveSummary>.from(entry.value)
        ..sort((a, b) {
          final levelA = a.level ?? 999;
          final levelB = b.level ?? 999;
          final levelComparison = levelA.compareTo(levelB);
          if (levelComparison != 0) return levelComparison;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return _MethodGroup(id: id, name: name, moves: sortedMoves);
    }).toList(growable: false)
      ..sort((a, b) {
        final rank = methodRank(a.id).compareTo(methodRank(b.id));
        if (rank != 0) return rank;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return groups;
  }
}
class _VersionOption {
  const _VersionOption({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int sortOrder;
}

class _MethodGroup {
  const _MethodGroup({
    required this.id,
    required this.name,
    required this.moves,
  });

  final String id;
  final String name;
  final List<PokemonMoveSummary> moves;
}

class _MoveGroupCard extends StatelessWidget {
  const _MoveGroupCard({
    required this.group,
    required this.selectedVersionGroupId,
  });

  final _MethodGroup group;
  final int? selectedVersionGroupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final move in group.moves) ...[
              _MoveListTile(
                move: move,
                selectedVersionGroupId: selectedVersionGroupId,
              ),
              if (move != group.moves.last) const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoveListTile extends StatelessWidget {
  const _MoveListTile({
    required this.move,
    required this.selectedVersionGroupId,
  });

  final PokemonMoveSummary move;
  final int? selectedVersionGroupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaParts = <String>[];
    if (move.damageClass.isNotEmpty) {
      metaParts.add(_titleCase(move.damageClass));
    }
    if (move.power != null) {
      metaParts.add('Power ${move.power}');
    }
    if (move.accuracy != null) {
      metaParts.add('Accuracy ${move.accuracy}%');
    }
    if (move.pp != null) {
      metaParts.add('PP ${move.pp}');
    }

    final filteredDetails = selectedVersionGroupId == null
        ? move.versionDetails
        : move.versionDetails
            .where((detail) => detail.versionGroupId == selectedVersionGroupId)
            .toList(growable: false);

    final displayDetails = filteredDetails.isNotEmpty
        ? filteredDetails
        : (selectedVersionGroupId == null
            ? move.versionDetails
            : const <PokemonMoveVersionDetail>[]);

    int? resolveLevel() {
      final Iterable<PokemonMoveVersionDetail> search =
          filteredDetails.isNotEmpty ? filteredDetails : move.versionDetails;
      for (final detail in search) {
        final level = detail.level;
        if (level != null && level > 0) {
          return level;
        }
      }
      return move.level;
    }

    final resolvedLevel = resolveLevel();
    final trailingLabel = resolvedLevel != null && resolvedLevel > 0
        ? 'Lv $resolvedLevel'
        : _titleCase(move.method);

    Widget buildVersionWrap() {
      if (selectedVersionGroupId != null && displayDetails.isEmpty) {
        return Text(
          'Unavailable in selected version',
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        );
      }
      if (displayDetails.isEmpty) {
        return const SizedBox.shrink();
      }
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: displayDetails.map((detail) {
          final label = detail.level != null && detail.level! > 0
              ? '${detail.versionGroupName} (Lv ${detail.level})'
              : detail.versionGroupName;
          return Chip(
            visualDensity: VisualDensity.compact,
            label: Text(label),
          );
        }).toList(growable: false),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_titleCase(move.name)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: () {
            final children = <Widget>[
              Text(
                metaParts.isEmpty
                    ? _titleCase(move.method)
                    : metaParts.join(' | '),
                style: theme.textTheme.bodySmall,
              ),
            ];
            final versionWidget = buildVersionWrap();
            final shouldShowVersion = !(versionWidget is SizedBox);
            if (shouldShowVersion) {
              children
                ..add(const SizedBox(height: 6))
                ..add(versionWidget);
            }
            return children;
          }(),
        ),
      ),
      leading: Chip(
        label: Text(_titleCase(move.type)),
      ),
      trailing: Text(
        trailingLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .join(' ');
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
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
