import '../../data/models/pokemon_models.dart';
import 'stat_presets.dart';

class MoveRecommendation {
  const MoveRecommendation({
    required this.move,
    required this.tags,
    required this.score,
    required this.isStab,
    required this.matchesPreset,
  });

  final PokemonMoveSummary move;
  final List<String> tags;
  final int score;
  final bool isStab;
  final bool matchesPreset;
}

List<MoveRecommendation> recommendMoves({
  required PokemonFormEntity form,
  required StatPreset preset,
  required int level,
  int? versionGroupId,
}) {
  if (form.moves.isEmpty) {
    return const <MoveRecommendation>[];
  }

  final types = form.types.map((type) => type.toLowerCase()).toSet();
  final preferredDamageClass = _preferredDamageClassForPreset(preset);
  final results = <MoveRecommendation>[];

  for (final move in form.moves) {
    if (!_isMoveAvailable(move, level, versionGroupId)) {
      continue;
    }

    final damageClass = move.damageClass.toLowerCase();
    final isStab = types.contains(move.type.toLowerCase());
    final matchesPreset = preferredDamageClass == null
        ? (preset == StatPreset.physicalWall ||
                preset == StatPreset.specialWall) &&
            damageClass == 'status'
        : damageClass == preferredDamageClass;

    var score = 0;
    if (isStab) {
      score += 40;
    }
    if (matchesPreset) {
      score += 60;
    }
    if (damageClass == 'status' &&
        (preset == StatPreset.physicalWall ||
            preset == StatPreset.specialWall)) {
      score += 50;
    }

    final power = move.power ?? 0;
    if (power > 0) {
      score += power;
    } else if (damageClass == 'status') {
      score += 20;
    }

    if (move.accuracy != null && move.accuracy! >= 95) {
      score += 5;
    }

    switch (move.methodId) {
      case 'machine':
        score += 10;
        break;
      case 'tutor':
        score += 8;
        break;
      case 'egg':
        score += 4;
        break;
      case 'level-up':
        score += 6;
        break;
    }

    if (preferredDamageClass != null && damageClass != preferredDamageClass) {
      score -= 30;
    }

    score += _keywordBonus(move.name, preset);

    if (score <= 0) {
      continue;
    }

    final tags = _buildMoveTags(
      move: move,
      isStab: isStab,
    );

    results.add(
      MoveRecommendation(
        move: move,
        tags: tags,
        score: score,
        isStab: isStab,
        matchesPreset: matchesPreset,
      ),
    );
  }

  results.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.move.name.compareTo(b.move.name);
  });

  return results.take(3).toList(growable: false);
}

String? _preferredDamageClassForPreset(StatPreset preset) {
  switch (preset) {
    case StatPreset.physicalSweeper:
      return 'physical';
    case StatPreset.specialSweeper:
      return 'special';
    case StatPreset.physicalWall:
    case StatPreset.specialWall:
      return 'status';
    case StatPreset.neutral:
      return null;
  }
}

bool _isMoveAvailable(
  PokemonMoveSummary move,
  int targetLevel,
  int? versionGroupId,
) {
  if (versionGroupId != null &&
      !move.versionDetails
          .any((detail) => detail.versionGroupId == versionGroupId)) {
    return false;
  }

  if (move.methodId == 'level-up' && move.level != null && move.level! > 0) {
    return move.level! <= targetLevel;
  }
  return true;
}

List<String> _buildMoveTags({
  required PokemonMoveSummary move,
  required bool isStab,
}) {
  final tags = <String>[];
  if (isStab) {
    tags.add('STAB');
  }
  final damageLabel = _formatDamageClass(move.damageClass);
  if (damageLabel != null) {
    tags.add(damageLabel);
  }
  if (move.power != null && move.power! > 0) {
    tags.add('${move.power} BP');
  } else if (move.damageClass.toLowerCase() == 'status') {
    tags.add('Status');
  }
  if (move.methodId == 'level-up') {
    final requiredLevel = move.level;
    if (requiredLevel != null && requiredLevel > 0) {
      tags.add('Lv $requiredLevel');
    }
  } else {
    tags.add(move.method);
  }
  return tags;
}

String? _formatDamageClass(String damageClass) {
  switch (damageClass.toLowerCase()) {
    case 'physical':
      return 'Physical';
    case 'special':
      return 'Special';
    case 'status':
      return null;
    default:
      return null;
  }
}

int _keywordBonus(String moveName, StatPreset preset) {
  final slug = moveName.toLowerCase().replaceAll(' ', '-');
  final bonus = _moveKeywordBonuses[slug] ?? 0;
  if (bonus == 0) {
    return 0;
  }
  if (preset == StatPreset.neutral) {
    return (bonus / 2).round();
  }
  return bonus;
}

const Map<String, int> _moveKeywordBonuses = <String, int>{
  'swords-dance': 30,
  'dragon-dance': 28,
  'bulk-up': 28,
  'calm-mind': 28,
  'nasty-plot': 32,
  'shell-smash': 35,
  'agility': 18,
  'rock-polish': 18,
  'quiver-dance': 32,
  'iron-defense': 26,
  'acid-armor': 26,
  'barrier': 24,
  'protect': 16,
  'detect': 16,
  'reflect': 24,
  'light-screen': 24,
  'recover': 34,
  'roost': 34,
  'soft-boiled': 34,
  'synthesis': 28,
  'moonlight': 28,
  'rest': 20,
  'leech-seed': 22,
  'will-o-wisp': 20,
  'toxic': 18,
  'stealth-rock': 26,
  'spikes': 24,
  'toxic-spikes': 24,
  'sticky-web': 24,
  'substitute': 20,
};
