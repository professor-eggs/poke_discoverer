import 'package:flutter/material.dart';

import '../../bootstrap.dart' show appDependencies, initializeDependencies;
import '../../data/models/pokemon_models.dart';
import '../detail/pokemon_detail_page.dart';

class PokemonCatalogPage extends StatefulWidget {
  const PokemonCatalogPage({super.key});

  @override
  State<PokemonCatalogPage> createState() => _PokemonCatalogPageState();
}

class _PokemonCatalogPageState extends State<PokemonCatalogPage> {
  static const _emptyMessage =
      'No cached Pokemon available yet. Seed the snapshot to view entries.';
  static const _noResultsMessage =
      'No Pokemon match the current filters. Adjust search or clear filters.';
  static const _searchFieldKey = Key('pokemonCatalogSearchField');

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTypes = <String>{};

  bool _isLoading = true;
  bool _isSeeding = false;
  String? _errorMessage;

  List<PokemonEntity> _allPokemon = const [];
  List<PokemonEntity> _visiblePokemon = const [];
  List<String> _availableTypes = const [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokemon Catalog'),
        actions: [
          IconButton(
            icon: _isSeeding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: 'Seed snapshot',
            onPressed: _isSeeding ? null : _seedSnapshot,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load catalog: $_errorMessage',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_allPokemon.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(_emptyMessage, textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: _searchFieldKey,
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search by name or number',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchTerm.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                      tooltip: 'Clear search',
                    ),
            ),
            onChanged: _handleSearchChanged,
          ),
        ),
        if (_availableTypes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTypes
                    .map(
                      (type) => FilterChip(
                        label: Text(_formatLabel(type)),
                        selected: _selectedTypes.contains(type),
                        onSelected: (_) => _toggleType(type),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _visiblePokemon.isEmpty
              ? _buildNoResultsView()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  itemCount: _visiblePokemon.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final pokemon = _visiblePokemon[index];
                    return _PokemonListTile(
                      pokemon: pokemon,
                      onTap: () => _openDetail(pokemon),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(_noResultsMessage, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pokemon = await appDependencies.catalogService.getCachedPokemon(
        limit: null,
      );
      if (!mounted) {
        return pokemon.length;
      }

      final types = _deriveTypes(pokemon);
      final filtered = _applyFilters(
        pokemon,
        searchTerm: _searchTerm,
        selectedTypes: _selectedTypes,
      );

      setState(() {
        _allPokemon = pokemon;
        _visiblePokemon = filtered;
        _availableTypes = types;
        _isLoading = false;
      });

      return pokemon.length;
    } catch (error) {
      if (!mounted) {
        return 0;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
        _allPokemon = const [];
        _visiblePokemon = const [];
        _availableTypes = const [];
      });
      return 0;
    }
  }

  Future<void> _seedSnapshot() async {
    setState(() {
      _isSeeding = true;
    });
    try {
      final updatedDependencies = await initializeDependencies(
        forceImport: true,
      );
      appDependencies = updatedDependencies;
      final count = await _loadCatalog();
      _showSnack('Seed complete. Cached Pokemon: $count');
    } catch (error) {
      _showSnack('Failed to seed snapshot: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }

  void _openDetail(PokemonEntity pokemon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PokemonDetailPage(pokemonId: pokemon.id),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    _searchTerm = value.trim();
    setState(() {
      _visiblePokemon = _applyFilters(
        _allPokemon,
        searchTerm: _searchTerm,
        selectedTypes: _selectedTypes,
      );
    });
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
      _visiblePokemon = _applyFilters(
        _allPokemon,
        searchTerm: _searchTerm,
        selectedTypes: _selectedTypes,
      );
    });
  }

  void _clearSearch() {
    if (_searchTerm.isEmpty) return;
    _searchTerm = '';
    _searchController.clear();
    setState(() {
      _visiblePokemon = _applyFilters(
        _allPokemon,
        searchTerm: _searchTerm,
        selectedTypes: _selectedTypes,
      );
    });
  }

  void _clearFilters() {
    if (_searchTerm.isEmpty && _selectedTypes.isEmpty) return;
    _searchTerm = '';
    _selectedTypes.clear();
    _searchController.clear();
    setState(() {
      _visiblePokemon = _applyFilters(
        _allPokemon,
        searchTerm: _searchTerm,
        selectedTypes: _selectedTypes,
      );
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static List<String> _deriveTypes(List<PokemonEntity> pokemon) {
    final uniqueTypes = <String>{};
    for (final entity in pokemon) {
      uniqueTypes.addAll(
        entity.defaultForm.types.map((type) => type.toLowerCase()),
      );
    }
    final sorted = uniqueTypes.toList(growable: false)..sort();
    return sorted;
  }

  static List<PokemonEntity> _applyFilters(
    List<PokemonEntity> source, {
    required String searchTerm,
    required Set<String> selectedTypes,
  }) {
    final query = searchTerm.trim().toLowerCase();
    return source
        .where((pokemon) {
          final matchesQuery =
              query.isEmpty ||
              pokemon.name.toLowerCase().contains(query) ||
              pokemon.id.toString().contains(query) ||
              pokemon.id.toString().padLeft(3, '0').contains(query);
          if (!matchesQuery) {
            return false;
          }
          if (selectedTypes.isEmpty) {
            return true;
          }
          final formTypes = pokemon.defaultForm.types
              .map((type) => type.toLowerCase())
              .toSet();
          return selectedTypes.every(formTypes.contains);
        })
        .toList(growable: false);
  }

  static String _formatLabel(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _PokemonListTile extends StatelessWidget {
  const _PokemonListTile({required this.pokemon, required this.onTap});

  final PokemonEntity pokemon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final defaultForm = pokemon.defaultForm;
    final typeLabel = defaultForm.types
        .map(
          (type) =>
              type.isEmpty ? type : type[0].toUpperCase() + type.substring(1),
        )
        .join(' / ');
    final baseStatTotal = defaultForm.stats.fold<int>(
      0,
      (total, stat) => total + stat.baseValue,
    );

    return ListTile(
      leading: Text(
        '#${pokemon.id.toString().padLeft(3, '0')}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      title: Text(_capitalize(pokemon.name)),
      subtitle: Text(typeLabel),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'BST $baseStatTotal',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  static String _capitalize(String name) {
    if (name.isEmpty) {
      return name;
    }
    return name[0].toUpperCase() + name.substring(1);
  }
}
