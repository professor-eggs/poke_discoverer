import 'package:flutter/material.dart';

import '../../bootstrap.dart' show appDependencies, initializeDependencies;
import '../../data/models/pokemon_models.dart';
import '../detail/pokemon_detail_page.dart';
import '../comparison/pokemon_comparison_page.dart';
import '../widgets/sprite_avatar.dart';

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
  static const _sortLabels = <CatalogSort, String>{
    CatalogSort.dex: 'Dex number',
    CatalogSort.name: 'Name',
    CatalogSort.total: 'Base stat total',
    CatalogSort.hp: 'HP',
    CatalogSort.atk: 'Attack',
    CatalogSort.def: 'Defense',
    CatalogSort.spa: 'Sp. Attack',
    CatalogSort.spd: 'Sp. Defense',
    CatalogSort.spe: 'Speed',
  };
  static const _maxComparisonSelections = 6;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTypes = <String>{};
  final Set<int> _selectedPokemonIds = <int>{};

  bool _isLoading = true;
  bool _isSeeding = false;
  String? _errorMessage;

  List<PokemonEntity> _allPokemon = const [];
  List<PokemonEntity> _visiblePokemon = const [];
  List<String> _availableTypes = const [];
  String _searchTerm = '';
  CatalogSort _sort = CatalogSort.dex;
  bool _sortAscending = true;

  bool get _hasSelection => _selectedPokemonIds.isNotEmpty;
  bool get _canCompare => _selectedPokemonIds.length >= 2;
  bool get _canAddMoreSelections =>
      _selectedPokemonIds.length < _maxComparisonSelections;

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
      bottomNavigationBar: _hasSelection ? _buildSelectionBar() : null,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<CatalogSort>(
                  value: _sort,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(),
                  ),
                  items: CatalogSort.values
                      .map(
                        (value) => DropdownMenuItem<CatalogSort>(
                          value: value,
                          child: Text(_sortLabels[value]!),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _sort = value;
                      _sortVisiblePokemon();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _sortAscending ? 'Ascending' : 'Descending',
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                    _sortVisiblePokemon();
                  });
                },
              ),
            ],
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
                    final isSelected = _selectedPokemonIds.contains(pokemon.id);
                    final selectionEnabled =
                        isSelected || _canAddMoreSelections;
                    return _PokemonListTile(
                      pokemon: pokemon,
                      isSelected: isSelected,
                      isSelectionMode: _hasSelection,
                      selectionEnabled: selectionEnabled,
                      onTap: () => _handleTileTap(pokemon),
                      onToggleSelection: () => _toggleSelection(pokemon),
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

  Widget _buildSelectionBar() {
    final theme = Theme.of(context);
    final selectedEntities = _selectedPokemonIds
        .map(_findPokemonById)
        .whereType<PokemonEntity>()
        .toList(growable: false);

    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedPokemonIds.length} selected',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canCompare ? _openComparison : null,
                    child: Text('Compare (${_selectedPokemonIds.length})'),
                  ),
                ],
              ),
              if (selectedEntities.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedEntities
                      .map(
                        (pokemon) => InputChip(
                          label: Text(_formatPokemonLabel(pokemon)),
                          onDeleted: () => _toggleSelection(pokemon),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
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
      final validSelection = _selectedPokemonIds
          .where((id) => pokemon.any((entity) => entity.id == id))
          .toList(growable: false);

      final sorted = _sortPokemon(filtered);
      setState(() {
        _allPokemon = pokemon;
        _visiblePokemon = sorted;
        _availableTypes = types;
        _isLoading = false;
        _selectedPokemonIds
          ..clear()
          ..addAll(validSelection);
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

  void _handleTileTap(PokemonEntity pokemon) {
    if (_hasSelection) {
      _toggleSelection(pokemon);
    } else {
      _openPokemonDetail(pokemon);
    }
  }

  void _toggleSelection(PokemonEntity pokemon) {
    final id = pokemon.id;
    if (_selectedPokemonIds.contains(id)) {
      setState(() {
        _selectedPokemonIds.remove(id);
      });
    } else {
      if (!_canAddMoreSelections) {
        _showSnack(
          'Select up to $_maxComparisonSelections Pokemon for comparison.',
        );
        return;
      }
      setState(() {
        _selectedPokemonIds.add(id);
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedPokemonIds.clear();
    });
  }

  void _openComparison() {
    if (!_canCompare) return;
    final ids = _selectedPokemonIds.toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PokemonComparisonPage(pokemonIds: ids),
      ),
    );
  }

  void _openPokemonDetail(PokemonEntity pokemon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PokemonDetailPage(pokemonId: pokemon.id),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    _searchTerm = value.trim();
    final filtered = _applyFilters(
      _allPokemon,
      searchTerm: _searchTerm,
      selectedTypes: _selectedTypes,
    );
    setState(() {
      _visiblePokemon = _sortPokemon(filtered);
    });
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
      final filtered = _applyFilters(
        _allPokemon,
        searchTerm: _searchTerm,
        selectedTypes: _selectedTypes,
      );
      _visiblePokemon = _sortPokemon(filtered);
    });
  }

  void _clearSearch() {
    if (_searchTerm.isEmpty) return;
    _searchTerm = '';
    _searchController.clear();
    final filtered = _applyFilters(
      _allPokemon,
      searchTerm: _searchTerm,
      selectedTypes: _selectedTypes,
    );
    setState(() {
      _visiblePokemon = _sortPokemon(filtered);
    });
  }

  void _clearFilters() {
    if (_searchTerm.isEmpty && _selectedTypes.isEmpty) return;
    _searchTerm = '';
    _selectedTypes.clear();
    _searchController.clear();
    final filtered = _applyFilters(
      _allPokemon,
      searchTerm: _searchTerm,
      selectedTypes: _selectedTypes,
    );
    setState(() {
      _visiblePokemon = _sortPokemon(filtered);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  PokemonEntity? _findPokemonById(int id) {
    for (final pokemon in _allPokemon) {
      if (pokemon.id == id) {
        return pokemon;
      }
    }
    return null;
  }

  String _formatPokemonLabel(PokemonEntity pokemon) {
    final number = '#${pokemon.id.toString().padLeft(3, '0')}';
    final name = _PokemonListTile._capitalize(pokemon.name);
    return '$number $name';
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

  List<PokemonEntity> _sortPokemon(List<PokemonEntity> source) {
    final list = List<PokemonEntity>.from(source);
    list.sort((a, b) {
      int compare;
      switch (_sort) {
        case CatalogSort.dex:
          compare = a.id.compareTo(b.id);
          break;
        case CatalogSort.name:
          compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case CatalogSort.total:
          compare = _catalogBaseStatTotal(
            a,
          ).compareTo(_catalogBaseStatTotal(b));
          break;
        case CatalogSort.hp:
        case CatalogSort.atk:
        case CatalogSort.def:
        case CatalogSort.spa:
        case CatalogSort.spd:
        case CatalogSort.spe:
          final statId = _statIdForSort(_sort);
          final aStat = a.defaultForm.baseStat(statId) ?? 0;
          final bStat = b.defaultForm.baseStat(statId) ?? 0;
          compare = aStat.compareTo(bStat);
          break;
      }
      if (compare == 0) {
        compare = a.id.compareTo(b.id);
      }
      return _sortAscending ? compare : -compare;
    });
    return list;
  }

  void _sortVisiblePokemon() {
    _visiblePokemon = _sortPokemon(_visiblePokemon);
  }

  static String _statIdForSort(CatalogSort sort) {
    switch (sort) {
      case CatalogSort.hp:
        return 'hp';
      case CatalogSort.atk:
        return 'atk';
      case CatalogSort.def:
        return 'def';
      case CatalogSort.spa:
        return 'spa';
      case CatalogSort.spd:
        return 'spd';
      case CatalogSort.spe:
        return 'spe';
      default:
        return '';
    }
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
  const _PokemonListTile({
    required this.pokemon,
    required this.isSelected,
    required this.isSelectionMode,
    required this.selectionEnabled,
    required this.onTap,
    required this.onToggleSelection,
  });

  final PokemonEntity pokemon;
  final bool isSelected;
  final bool isSelectionMode;
  final bool selectionEnabled;
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    final tileColor = isSelected
        ? theme.colorScheme.primaryContainer.withOpacity(0.35)
        : (isSelectionMode
              ? theme.colorScheme.surfaceVariant.withOpacity(0.25)
              : null);

    final textColor = isSelected ? theme.colorScheme.onPrimaryContainer : null;

    return ListTile(
      key: ValueKey('pokemon-${pokemon.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _CatalogLeadingSprite(
        pokemon: pokemon,
        textStyle: theme.textTheme.labelLarge?.copyWith(color: textColor),
      ),
      title: Text(
        _capitalize(pokemon.name),
        style: theme.textTheme.titleMedium?.copyWith(color: textColor),
      ),
      subtitle: Text(
        typeLabel,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'BST $baseStatTotal',
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
          const SizedBox(width: 12),
          Checkbox(
            key: ValueKey('pokemon-${pokemon.id}-checkbox'),
            value: isSelected,
            onChanged: selectionEnabled ? (_) => onToggleSelection() : null,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      tileColor: tileColor,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.6),
      selectedColor: theme.colorScheme.onPrimaryContainer,
      visualDensity: VisualDensity.compact,
      onTap: onTap,
      onLongPress: onToggleSelection,
    );
  }

  static String _capitalize(String name) {
    if (name.isEmpty) {
      return name;
    }
    return name[0].toUpperCase() + name.substring(1);
  }
}

class _CatalogLeadingSprite extends StatelessWidget {
  const _CatalogLeadingSprite({
    required this.pokemon,
    required this.textStyle,
  });

  final PokemonEntity pokemon;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '#${pokemon.id.toString().padLeft(3, '0')}',
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          SpriteAvatar(pokemon: pokemon, size: 32),
        ],
      ),
    );
  }
}

enum CatalogSort { dex, name, total, hp, atk, def, spa, spd, spe }

int _catalogBaseStatTotal(PokemonEntity pokemon) {
  return pokemon.defaultForm.stats.fold<int>(
    0,
    (total, stat) => total + stat.baseValue,
  );
}
