import 'package:equatable/equatable.dart';

class PokemonEntity extends Equatable {
  const PokemonEntity({
    required this.id,
    required this.name,
    required this.speciesId,
    required this.forms,
  });

  final int id;
  final String name;
  final int speciesId;
  final List<PokemonFormEntity> forms;

  PokemonFormEntity get defaultForm =>
      forms.firstWhere((form) => form.isDefault, orElse: () => forms.first);

  @override
  List<Object?> get props => [id, name, speciesId, forms];
}

class PokemonFormEntity extends Equatable {
  const PokemonFormEntity({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.types,
    required this.stats,
    required this.sprites,
    required this.moves,
  });

  final int id;
  final String name;
  final bool isDefault;
  final List<String> types;
  final List<PokemonStatValue> stats;
  final List<MediaAssetReference> sprites;
  final List<PokemonMoveSummary> moves;

  int? baseStat(String statId) =>
      stats.firstWhereOrNull((stat) => stat.statId == statId)?.baseValue;

  @override
  List<Object?> get props => [
        id,
        name,
        isDefault,
        types,
        stats,
        sprites,
        moves,
      ];
}

class PokemonStatValue extends Equatable {
  const PokemonStatValue({
    required this.statId,
    required this.baseValue,
  });

  final String statId;
  final int baseValue;

  @override
  List<Object?> get props => [statId, baseValue];
}

enum MediaAssetKind { sprite, icon, audio }

class MediaAssetReference extends Equatable {
  const MediaAssetReference({
    required this.assetId,
    required this.kind,
    this.localPath,
    this.remoteUrl,
  });

  final String assetId;
  final MediaAssetKind kind;
  final String? localPath;
  final Uri? remoteUrl;

  @override
  List<Object?> get props => [assetId, kind, localPath, remoteUrl];
}

class PokemonMoveSummary extends Equatable {
  const PokemonMoveSummary({
    required this.moveId,
    required this.methodId,
    required this.name,
    required this.method,
    required this.type,
    required this.damageClass,
    required this.versionDetails,
    this.level,
    this.power,
    this.accuracy,
    this.pp,
  });

  final int moveId;
  final String methodId;
  final String name;
  final String method;
  final String type;
  final String damageClass;
  final List<PokemonMoveVersionDetail> versionDetails;
  final int? level;
  final int? power;
  final int? accuracy;
  final int? pp;

  @override
  List<Object?> get props => [
        moveId,
        methodId,
        name,
        method,
        type,
        damageClass,
        versionDetails,
        level,
        power,
        accuracy,
        pp,
      ];
}

class PokemonMoveVersionDetail extends Equatable {
  const PokemonMoveVersionDetail({
    required this.versionGroupId,
    required this.versionGroupName,
    required this.sortOrder,
    this.level,
  });

  final int versionGroupId;
  final String versionGroupName;
  final int sortOrder;
  final int? level;

  @override
  List<Object?> get props => [
        versionGroupId,
        versionGroupName,
        sortOrder,
        level,
      ];
}

extension _IterableFirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) predicate) {
    for (final element in this) {
      if (predicate(element)) {
        return element;
      }
    }
    return null;
  }
}
