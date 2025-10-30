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
    return Scaffold(
      appBar: AppBar(
        title: Text('Pokemon #${widget.pokemonId.toString().padLeft(3, '0')}'),
      ),
      body: FutureBuilder<PokemonEntity?>(
        future: _pokemonFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(message: snapshot.error.toString());
          }
          final pokemon = snapshot.data;
          if (pokemon == null) {
            return const _ErrorView(
              message: 'Pokemon not found in local cache.',
            );
          }
          return _PokemonDetailBody(pokemon: pokemon);
        },
      ),
    );
  }
}

class _PokemonDetailBody extends StatelessWidget {
  const _PokemonDetailBody({required this.pokemon});

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
                    ).colorScheme.surfaceVariant,
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
          final progress = normalized.clamp(0.0, 1.0) as double;
          final background = theme.colorScheme.surfaceVariant.withOpacity(0.6);
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
          final summary = snapshot.data ??
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
  const _EffectivenessGroup({
    required this.title,
    required this.entries,
  });

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
