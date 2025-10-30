import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import 'pokemon_csv_loader.dart';

class _FileCsvLoader implements CsvLoader {
  _FileCsvLoader(this.root);

  final String root;

  @override
  Future<String> readCsvString(String fileName) async {
    final file = File(p.join(root, fileName));
    if (!await file.exists()) {
      throw FileSystemException('Missing CSV file', file.path);
    }
    return file.readAsString();
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
  if (filesystemRoot == null) {
    throw ArgumentError.notNull('filesystemRoot');
  }
  return _FileCsvLoader(filesystemRoot);
}
