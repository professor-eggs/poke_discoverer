import '../models/pokemon_models.dart';

/// Describes a battle stat profile including IV/EV and nature modifiers.
class StatCalculationProfile {
  const StatCalculationProfile({
    this.individualValue = 31,
    this.effortValues = const <String, int>{},
    this.natureMultipliers = const <String, double>{},
  });

  final int individualValue;
  final Map<String, int> effortValues;
  final Map<String, double> natureMultipliers;

  int effortFor(String statId) => effortValues[statId] ?? 0;
  double natureFor(String statId) => natureMultipliers[statId] ?? 1.0;
}

/// Computes Pokemon battle stats using the standard mainline formulae.
class PokemonStatCalculator {
  const PokemonStatCalculator({
    this.individualValue = 31,
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
    StatCalculationProfile? profile,
  }) {
    final stats = <String, int>{};
    final baseIndividualValue = profile?.individualValue ?? individualValue;

    for (final stat in pokemon.defaultForm.stats) {
      final isHp = stat.statId == 'hp';
      final ev = profile?.effortFor(stat.statId) ?? effortValue;
      final effectiveIv = baseIndividualValue;
      final nature = isHp
          ? 1.0
          : profile?.natureFor(stat.statId) ?? natureMultiplier;
      final value = isHp
          ? _computeHp(stat.baseValue, level, effectiveIv, ev)
          : _computeOther(stat.baseValue, level, effectiveIv, ev, nature);
      stats[stat.statId] = value;
    }
    return stats;
  }

  int _computeHp(int baseStat, int level, int individualValue, int effortValue) {
    if (baseStat == 1) {
      return 1;
    }
    final interim =
        ((2 * baseStat + individualValue + (effortValue ~/ 4)) * level) ~/ 100;
    return interim + level + 10;
  }

  int _computeOther(
    int baseStat,
    int level,
    int individualValue,
    int effortValue,
    double natureMultiplier,
  ) {
    final interim =
        ((2 * baseStat + individualValue + (effortValue ~/ 4)) * level) ~/ 100;
    final value = ((interim + 5) * natureMultiplier).floor();
    return value;
  }
}
