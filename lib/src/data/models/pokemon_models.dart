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
  });

  final int id;
  final String name;
  final bool isDefault;
  final List<String> types;
  final List<PokemonStatValue> stats;
  final List<MediaAssetReference> sprites;

  int? baseStat(String statId) =>
      stats.firstWhereOrNull((stat) => stat.statId == statId)?.baseValue;

  @override
  List<Object?> get props => [id, name, isDefault, types, stats, sprites];
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
