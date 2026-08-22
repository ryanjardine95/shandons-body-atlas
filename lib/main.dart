import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/atlas_screen.dart';
import 'src/manifest.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manifest = AtlasManifest.fromJsonString(
      await rootBundle.loadString('assets/models/atlas.json'));
  runApp(AtlasApp(manifest: manifest));
}

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key, required this.manifest});

  final AtlasManifest manifest;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Shandon's Body Atlas",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B8DEF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AtlasScreen(manifest: manifest),
    );
  }
}
