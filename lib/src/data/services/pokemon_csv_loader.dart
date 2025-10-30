import 'pokemon_csv_loader_stub.dart'
    if (dart.library.io) 'pokemon_csv_loader_io.dart'
    if (dart.library.html) 'pokemon_csv_loader_web.dart';

abstract class CsvLoader {
  Future<String> readCsvString(String fileName);

  Future<List<Map<String, String>>> readCsv(String fileName);
}

CsvLoader createCsvLoader({
  String? filesystemRoot,
  String? assetRoot,
}) {
  return createPlatformCsvLoader(
    filesystemRoot: filesystemRoot,
    assetRoot: assetRoot,
  );
}
