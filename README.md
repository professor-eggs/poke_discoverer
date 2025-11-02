# Manny's PokeApp – Developer Quickstart

This workspace powers Manny's PokeApp, a Flutter experience for browsing Pokémon data,
building teams, and running lightweight battle simulations. The stack is designed to
work offline by seeding an embedded SQLite cache from the official PokéAPI CSV exports.

## Prerequisites

- Flutter 3.x (Web, Windows, Android targets enabled)
- Dart SDK (bundled with Flutter)
- Git LFS if you intend to manage large CSV snapshots separately

After cloning, run:

```bash
flutter pub get
```

## Data Assets

The app bootstraps its cache from PokéAPI CSVs. Keep two copies of the dataset:

- `data/pokeapi-master/data/v2/csv/` – raw CSV dump used by local tooling/tests.
- `assets/pokeapi/csv/` – bundled subset for the web build (same layout; keep files in sync).

During development you can symlink or script updates between the folders, but the web
bundle must contain the CSVs under `assets/pokeapi/csv/` so they ship with the app.
After updating assets, run `flutter pub get` (or `flutter pub run build_runner` if caching)
to refresh the Flutter asset manifest.

## Web (Edge/Chrome/Safari) Support

SQLite on the web relies on `sqflite_common_ffi_web`. Run the following once per machine
to generate the required shared worker (`sqflite_sw.js`) and `sqlite3.wasm` binaries:

```bash
dart run sqflite_common_ffi_web:setup --force
```

The generated files are placed in the `web/` directory and are picked up automatically by
`flutter run -d edge` or `flutter build web`.

## Running Tests

```bash
flutter test
```

Unit tests cover repository behavior, CSV ingestion, and widget wiring. Integration tests
will be added as part of the phased delivery plan captured in `docs/erd-and-milestones.md`.

## Launching the App

- Native/Desktop: `flutter run`
- Web (Edge/Chrome): `flutter run -d edge`

Use the catalog screen’s “Seed data snapshot” action to import CSV data into SQLite on demand.
When running on the web the ingestion service reads from the bundled asset CSVs; on desktop it
reads directly from `data/pokeapi-master/data/v2/csv/`.

---

## Data Source & License

This app uses Pokémon data in CSV format from the [PokéAPI project](https://github.com/PokeAPI/pokeapi),
which is made available under the MIT License. See the [PokéAPI GitHub repository](https://github.com/PokeAPI/pokeapi) for details.


All Pokémon data and CSVs included in this repository are © PokéAPI contributors and used under the terms of the MIT License.

Pokémon sprites are © PokéAPI, used under the CC0 1.0 Universal license. See the [PokéAPI Sprites repository](https://github.com/PokeAPI/sprites) for details.
