import '../models/pokemon_models.dart';

/// Computes Pokemon battle stats using the standard mainline formulae.
class PokemonStatCalculator {
  const PokemonStatCalculator({
    this.individualValue = 15,
    this.effortValue = 0,
    this.natureMultiplier = 1.0,
  });

  final int individualValue;
  final int effortValue;
  final double natureMultiplier;

  /// Returns a map of stat id -> computed stat at the given [level].
  Map<String, int> computeStats({
    required PokemonEntity pokemon,
    required int level,
  }) {
    final stats = <String, int>{};
    for (final stat in pokemon.defaultForm.stats) {
      final isHp = stat.statId == 'hp';
      final value = isHp
          ? _computeHp(stat.baseValue, level)
          : _computeOther(stat.baseValue, level);
      stats[stat.statId] = value;
    }
    return stats;
  }

  int _computeHp(int baseStat, int level) {
    if (baseStat == 1) {
      return 1;
    }
    final interim =
        ((2 * baseStat + individualValue + (effortValue ~/ 4)) * level) ~/ 100;
    return interim + level + 10;
  }

  int _computeOther(int baseStat, int level) {
    final interim =
        ((2 * baseStat + individualValue + (effortValue ~/ 4)) * level) ~/ 100;
    final value = ((interim + 5) * natureMultiplier).floor();
    return value;
  }
}
