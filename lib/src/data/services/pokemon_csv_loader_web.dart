import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'pokemon_csv_loader.dart';

class _AssetCsvLoader implements CsvLoader {
  _AssetCsvLoader(this.assetRoot);

  final String assetRoot;

  @override
  Future<String> readCsvString(String fileName) async {
    final assetPath = p.join(assetRoot, fileName).replaceAll(r'\', '/');
    return rootBundle.loadString(assetPath);
  }

  @override
  Future<List<Map<String, String>>> readCsv(String fileName) async {
    final raw = await readCsvString(fileName);
    final normalized =
        raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((value) => value.toString()).toList();
    return rows
        .skip(1)
        .map(
          (row) => Map<String, String>.fromIterables(
            headers,
            row.map((value) => value?.toString() ?? ''),
          ),
        )
        .toList();
  }
}

CsvLoader createPlatformCsvLoader({
  String? filesystemRoot,
  String? assetRoot,
}) {
  if (assetRoot == null) {
    throw ArgumentError.notNull('assetRoot');
  }
  return _AssetCsvLoader(assetRoot);
}
