import 'package:flutter/material.dart';

import 'src/bootstrap.dart';
import 'src/presentation/catalog/pokemon_catalog_page.dart';

Future<void> main() async {
  await bootstrap();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon Catalog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PokemonCatalogPage(),
    );
  }
}
