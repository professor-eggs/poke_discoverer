import 'package:flutter/material.dart';

import '../../bootstrap.dart' show appDependencies;
import '../../data/models/pokemon_models.dart';

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
