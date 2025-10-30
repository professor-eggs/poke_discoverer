import 'package:flutter/material.dart';

import '../../data/models/pokemon_models.dart';

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
          backgroundColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.6),
      child: Text(
        pokemon.name.isEmpty ? '?' : pokemon.name[0].toUpperCase(),
        style: theme.textTheme.labelLarge,
      ),
    );

    final sprites = pokemon.defaultForm.sprites;
    final spriteRef = sprites.firstWhere(
      (sprite) => sprite.kind == MediaAssetKind.sprite,
      orElse: () =>
          sprites.isNotEmpty ? sprites.first : _fallbackSpriteReference,
    );

    if (spriteRef.localPath != null && spriteRef.localPath!.isNotEmpty) {
      return ClipOval(
        child: Image.asset(
          spriteRef.localPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    final remoteUrl = spriteRef.remoteUrl;
    if (remoteUrl != null) {
      return ClipOval(
        child: Image.network(
          remoteUrl.toString(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    return placeholder;
  }
}

const MediaAssetReference _fallbackSpriteReference = MediaAssetReference(
  assetId: 'sprite',
  kind: MediaAssetKind.sprite,
);
