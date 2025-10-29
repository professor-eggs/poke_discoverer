import 'package:equatable/equatable.dart';

enum DataSourceKind {
  pokeapiCsv,
}

class DataSourceSnapshot extends Equatable {
  const DataSourceSnapshot({
    required this.kind,
    required this.upstreamVersion,
    required this.checksum,
    required this.packagedAt,
    this.importedAt,
    this.sourceUri,
  });

  final DataSourceKind kind;
  final String upstreamVersion;
  final String checksum;
  final DateTime packagedAt;
  final DateTime? importedAt;
  final Uri? sourceUri;

  DataSourceSnapshot copyWith({
    DataSourceKind? kind,
    String? upstreamVersion,
    String? checksum,
    DateTime? packagedAt,
    DateTime? importedAt,
    Uri? sourceUri,
  }) {
    return DataSourceSnapshot(
      kind: kind ?? this.kind,
      upstreamVersion: upstreamVersion ?? this.upstreamVersion,
      checksum: checksum ?? this.checksum,
      packagedAt: packagedAt ?? this.packagedAt,
      importedAt: importedAt ?? this.importedAt,
      sourceUri: sourceUri ?? this.sourceUri,
    );
  }

  @override
  List<Object?> get props => [
        kind,
        upstreamVersion,
        checksum,
        packagedAt,
        importedAt,
        sourceUri,
      ];
}
