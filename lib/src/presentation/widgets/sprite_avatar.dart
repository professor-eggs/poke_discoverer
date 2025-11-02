import 'package:flutter/material.dart';
import '../../data/models/pokemon_models.dart';

/// Returns the sprite URL for a given Pokémon form, using the user's GitHub repo.
/// Supports base forms and alternate forms by formId.
/// Returns the sprite URL for a given Pokémon form, using a configurable base URL.
/// The base URL can be set at build time with --dart-define=SPRITE_BASE_URL=...
const String _defaultSpriteBaseUrl = 'https://raw.githubusercontent.com/professor-eggs/poke-discoverer-sprites/refs/heads/main/sprites/pokemon/';
const String spriteBaseUrl = String.fromEnvironment('SPRITE_BASE_URL', defaultValue: _defaultSpriteBaseUrl);

String getSpriteUrl({required int formId, bool shiny = false}) {
  final suffix = shiny ? '_shiny' : '';
  return '${spriteBaseUrl}${formId}${suffix}.png?raw=true';
}

class SpriteAvatar extends StatelessWidget {
  const SpriteAvatar({
    super.key,
    required this.pokemon,
    this.size = 40,
    this.backgroundColor,
  });

  final PokemonEntity pokemon;
  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = CircleAvatar(
      radius: size / 2,
      backgroundColor:
          backgroundColor ??
          theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
      child: Text(
        pokemon.name.isEmpty ? '?' : pokemon.name[0].toUpperCase(),
        style: theme.textTheme.labelLarge,
      ),
    );

    final form = pokemon.defaultForm;
    final spriteUrl = getSpriteUrl(formId: form.id);

    return ClipOval(
      child: Image.network(
        spriteUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
