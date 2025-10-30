import '../services/pokemon_csv_loader.dart';

CsvLoader createPlatformCsvLoader({
  String? filesystemRoot,
  String? assetRoot,
}) =>
    throw UnsupportedError('CSV loader not supported on this platform.');
