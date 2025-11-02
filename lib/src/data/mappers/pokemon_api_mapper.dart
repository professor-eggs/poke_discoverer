import '../models/pokemon_models.dart';

class PokemonApiMapper {
  const PokemonApiMapper._();

  static PokemonEntity fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final name = _asString(json['name']);
    final species = json['species'] as Map<String, dynamic>? ?? const {};
    final speciesId = _extractIdFromUrl(species['url']) ?? id;

    final stats = _mapStats(json['stats'] as List?);
    final types = _mapTypes(json['types'] as List?);
    final sprites = _mapSprites(
      json['sprites'] as Map<String, dynamic>? ?? const {},
      pokemonId: id,
    );

    final formsJson = json['forms'] as List<dynamic>? ?? const [];
    final isDefaultFlag = json['is_default'] as bool? ?? true;

    final List<PokemonFormEntity> forms = formsJson.isEmpty
        ? [
            PokemonFormEntity(
              id: id,
              name: name,
              isDefault: isDefaultFlag,
              types: types,
              stats: stats,
              sprites: sprites,
              moves: const [],
            ),
          ]
        : formsJson
            .map((raw) => _mapForm(
                  raw as Map<String, dynamic>,
                  defaultName: name,
                  defaultStats: stats,
                  defaultTypes: types,
                  defaultSprites: sprites,
                  fallbackId: id,
                  fallbackDefaultFlag: isDefaultFlag,
                ))
            .cast<PokemonFormEntity>()
            .toList(growable: false);

    return PokemonEntity(
      id: id,
      name: name,
      speciesId: speciesId,
      forms: forms,
    );
  }

  static PokemonFormEntity _mapForm(
    Map<String, dynamic> json, {
    required String defaultName,
    required List<String> defaultTypes,
    required List<PokemonStatValue> defaultStats,
    required List<MediaAssetReference> defaultSprites,
    required int fallbackId,
    required bool fallbackDefaultFlag,
  }) {
    final formName = _asString(json['name']);
    final isDefault = formName == defaultName ? fallbackDefaultFlag : false;
    final formId = _extractIdFromUrl(json['url']) ?? fallbackId;

    return PokemonFormEntity(
      id: formId,
      name: formName,
      isDefault: isDefault,
      types: defaultTypes,
      stats: defaultStats,
      sprites: defaultSprites,
      moves: const [],
    );
  }

  static List<PokemonStatValue> _mapStats(List? statsJson) {
    if (statsJson == null) return const [];
    return statsJson
        .whereType<Map<String, dynamic>>()
        .map((statJson) {
          final stat = statJson['stat'] as Map<String, dynamic>? ?? const {};
          final statName = _asString(stat['name']).toLowerCase();
          final base = _asInt(statJson['base_stat']);
          return PokemonStatValue(statId: statName, baseValue: base);
        })
        .toList(growable: false);
  }

  static List<String> _mapTypes(List? typesJson) {
    if (typesJson == null) return const [];
    return typesJson
        .whereType<Map<String, dynamic>>()
        .map((typeJson) {
          final type = typeJson['type'] as Map<String, dynamic>? ?? const {};
          return _asString(type['name']).toLowerCase();
        })
        .toList(growable: false);
  }

  static List<MediaAssetReference> _mapSprites(
    Map<String, dynamic> spritesJson, {
    required int pokemonId,
  }) {
    final frontDefault = spritesJson['front_default'] as String?;
    if (frontDefault == null || frontDefault.isEmpty) {
      return const [];
    }
    return [
      MediaAssetReference(
        assetId: 'sprite:pokemon:$pokemonId:front-default',
        kind: MediaAssetKind.sprite,
        remoteUrl: Uri.tryParse(frontDefault),
      ),
    ];
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException('Expected int, got $value');
  }

  static String _asString(Object? value) {
    if (value is String) return value;
    throw FormatException('Expected string, got $value');
  }

  static int? _extractIdFromUrl(Object? url) {
    if (url is! String) return null;
    final match = RegExp(r'(\d+)/?$').firstMatch(url);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
