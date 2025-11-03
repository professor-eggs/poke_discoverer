import '../../data/services/pokemon_stat_calculator.dart';

enum StatPreset {
  neutral,
  physicalSweeper,
  specialSweeper,
  physicalWall,
  specialWall,
}

extension StatPresetData on StatPreset {
  String get label {
    switch (this) {
      case StatPreset.neutral:
        return 'Neutral';
      case StatPreset.physicalSweeper:
        return 'Physical sweeper';
      case StatPreset.specialSweeper:
        return 'Special sweeper';
      case StatPreset.physicalWall:
        return 'Physical wall';
      case StatPreset.specialWall:
        return 'Special wall';
    }
  }

  String get shortLabel {
    switch (this) {
      case StatPreset.neutral:
        return 'Neutral';
      case StatPreset.physicalSweeper:
        return 'Phys. Sweep';
      case StatPreset.specialSweeper:
        return 'Sp. Sweep';
      case StatPreset.physicalWall:
        return 'Phys. Wall';
      case StatPreset.specialWall:
        return 'Sp. Wall';
    }
  }

  String get description {
    switch (this) {
      case StatPreset.neutral:
        return 'No EV investment, neutral nature.';
      case StatPreset.physicalSweeper:
        return '+Atk / max Speed EVs, Adamant nature.';
      case StatPreset.specialSweeper:
        return '+Sp. Atk / max Speed EVs, Modest nature.';
      case StatPreset.physicalWall:
        return '+Def / max HP EVs, Impish nature.';
      case StatPreset.specialWall:
        return '+Sp. Def / max HP EVs, Careful nature.';
    }
  }

  StatCalculationProfile get profile {
    switch (this) {
      case StatPreset.neutral:
        return const StatCalculationProfile(individualValue: 31);
      case StatPreset.physicalSweeper:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'atk': 252, 'spe': 252, 'hp': 4},
          natureMultipliers: <String, double>{'atk': 1.1, 'spa': 0.9},
        );
      case StatPreset.specialSweeper:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'spa': 252, 'spe': 252, 'hp': 4},
          natureMultipliers: <String, double>{'spa': 1.1, 'atk': 0.9},
        );
      case StatPreset.physicalWall:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'hp': 252, 'def': 252, 'spd': 4},
          natureMultipliers: <String, double>{'def': 1.1, 'spe': 0.9},
        );
      case StatPreset.specialWall:
        return const StatCalculationProfile(
          individualValue: 31,
          effortValues: <String, int>{'hp': 252, 'spd': 252, 'def': 4},
          natureMultipliers: <String, double>{'spd': 1.1, 'spe': 0.9},
        );
    }
  }

  List<String> get highlightBadges {
    switch (this) {
      case StatPreset.neutral:
        return const ['Balanced'];
      case StatPreset.physicalSweeper:
        return const ['Atk+', 'Speed+', 'Prefers Physical'];
      case StatPreset.specialSweeper:
        return const ['Sp. Atk+', 'Speed+', 'Prefers Special'];
      case StatPreset.physicalWall:
        return const ['HP+', 'Def+', 'Status / Utility'];
      case StatPreset.specialWall:
        return const ['HP+', 'Sp. Def+', 'Status / Utility'];
    }
  }

  String get tooltip {
    final badges = highlightBadges.join(' | ');
    return '${label.toUpperCase()}\n$badges';
  }
}
