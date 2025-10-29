import 'package:flutter/material.dart';

import '../../bootstrap.dart';
import '../../data/models/pokemon_models.dart';

class PokemonCatalogPage extends StatefulWidget {
  const PokemonCatalogPage({super.key});

  @override
  State<PokemonCatalogPage> createState() => _PokemonCatalogPageState();
}

class _PokemonCatalogPageState extends State<PokemonCatalogPage> {
  late Future<List<PokemonEntity>> _catalogFuture;
  static const _emptyMessage =
      'No cached Pokémon available yet. Seed the snapshot to view entries.';

  @override
  void initState() {
    super.initState();
    _catalogFuture =
        appDependencies.catalogService.getCachedPokemon(limit: 200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon Catalog'),
      ),
      body: FutureBuilder<List<PokemonEntity>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load catalog: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          final data = snapshot.data ?? const [];
          if (data.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  _emptyMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final pokemon = data[index];
              final defaultForm = pokemon.defaultForm;
              final subtitle = defaultForm.types.join(' · ');
              return ListTile(
                leading: Text(
                  '#${pokemon.id.toString().padLeft(3, '0')}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                title: Text(_capitalize(pokemon.name)),
                subtitle: Text(subtitle),
              );
            },
          );
        },
      ),
    );
  }

  String _capitalize(String name) {
    if (name.isEmpty) {
      return name;
    }
    return name[0].toUpperCase() + name.substring(1);
  }
}
