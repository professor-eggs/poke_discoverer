import 'dart:convert';
import 'dart:io';

String readJsonFixture(String name) {
  final file = File('test/fixtures/$name');
  return file.readAsStringSync();
}

Map<String, dynamic> readJsonFixtureMap(String name) {
  final content = readJsonFixture(name);
  return json.decode(content) as Map<String, dynamic>;
}
