import 'dart:convert';

import '../models/cache_entry.dart';
import '../models/pokemon_models.dart';

class PokemonCacheMapper {
  const PokemonCacheMapper._();

  static const _columnId = 'pokemon_id';
  static const _columnJson = 'pokemon_json';
  static const _columnFetchedAt = 'last_fetched_ms';

  static Map<String, Object?> toDbRow(PokemonCacheEntry entry) {
    return {
      _columnId: entry.pokemonId,
      _columnJson: jsonEncode(_pokemonToJson(entry.pokemon)),
      _columnFetchedAt:
          entry.lastFetched.toUtc().millisecondsSinceEpoch,
    };
  }

  static PokemonCacheEntry fromDbRow(Map<String, Object?> row) {
    final pokemonMap = jsonDecode(row[_columnJson]! as String)
        as Map<String, dynamic>;
    return PokemonCacheEntry(
      pokemonId: row[_columnId] as int,
      pokemon: _pokemonFromJson(pokemonMap),
      lastFetched: DateTime.fromMillisecondsSinceEpoch(
        row[_columnFetchedAt] as int,
        isUtc: true,
      ),
    );
  }

  static Map<String, dynamic> _pokemonToJson(PokemonEntity entity) {
    return {
      'id': entity.id,
      'name': entity.name,
      'speciesId': entity.speciesId,
      'forms': entity.forms.map(_formToJson).toList(growable: false),
    };
  }

  static PokemonEntity _pokemonFromJson(Map<String, dynamic> json) {
    return PokemonEntity(
      id: json['id'] as int,
      name: json['name'] as String,
      speciesId: json['speciesId'] as int,
      forms: (json['forms'] as List<dynamic>)
          .map((raw) =>
              _formFromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> _formToJson(PokemonFormEntity form) {
    return {
      'id': form.id,
      'name': form.name,
      'isDefault': form.isDefault,
      'types': form.types,
      'stats':
          form.stats.map(_statToJson).toList(growable: false),
      'sprites':
          form.sprites.map(_spriteToJson).toList(growable: false),
    };
  }

  static PokemonFormEntity _formFromJson(
    Map<String, dynamic> json,
  ) {
    return PokemonFormEntity(
      id: json['id'] as int,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool,
      types: (json['types'] as List<dynamic>)
          .cast<String>()
          .toList(growable: false),
      stats: (json['stats'] as List<dynamic>)
          .map((raw) =>
              _statFromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
      sprites: (json['sprites'] as List<dynamic>)
          .map((raw) =>
              _spriteFromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> _statToJson(PokemonStatValue stat) {
    return {
      'statId': stat.statId,
      'baseValue': stat.baseValue,
    };
  }

  static PokemonStatValue _statFromJson(Map<String, dynamic> json) {
    return PokemonStatValue(
      statId: json['statId'] as String,
      baseValue: json['baseValue'] as int,
    );
  }

  static Map<String, dynamic> _spriteToJson(
    MediaAssetReference sprite,
  ) {
    return {
      'assetId': sprite.assetId,
      'kind': sprite.kind.name,
      'localPath': sprite.localPath,
      'remoteUrl': sprite.remoteUrl?.toString(),
    };
  }

  static MediaAssetReference _spriteFromJson(
    Map<String, dynamic> json,
  ) {
    final kindName = json['kind'] as String;
    final kind = MediaAssetKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => MediaAssetKind.sprite,
    );

    final remoteUrl = json['remoteUrl'] as String?;

    return MediaAssetReference(
      assetId: json['assetId'] as String,
      kind: kind,
      localPath: json['localPath'] as String?,
      remoteUrl:
          remoteUrl == null ? null : Uri.tryParse(remoteUrl),
    );
  }
}
