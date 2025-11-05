import 'package:flutter/material.dart';

import 'move_recommendations.dart';

class RecommendedMovesList extends StatelessWidget {
  const RecommendedMovesList({super.key, required this.moves});

  final List<MoveRecommendation> moves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (moves.isEmpty) {
      return Text(
        'No recommended moves for this selection.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final move in moves)
          Padding(
            padding: EdgeInsets.only(bottom: move == moves.last ? 0 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatMoveLabel(move.move.name),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: move.isStab || move.matchesPreset
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: move.isStab
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (move.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: move.tags
                        .map(
                          (tag) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(tag),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

String formatMoveLabel(String rawName) => _formatMoveLabel(rawName);

String _formatMoveLabel(String rawName) {
  final parts = rawName
      .toLowerCase()
      .split(RegExp(r'[- ]'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .toList(growable: false);
  return parts.isEmpty ? rawName : parts.join(' ');
}
