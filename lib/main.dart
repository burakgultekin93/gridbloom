import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/photo_store.dart';
import 'services/storage.dart';
import 'ui/home_screen.dart';
import 'ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Storage.init();
  await PhotoStore.load();
  runApp(const GridbloomApp());
}

class GridbloomApp extends StatelessWidget {
  const GridbloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gridbloom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.leaf, surface: Palette.background),
        scaffoldBackgroundColor: Palette.background,
        useMaterial3: true,
        fontFamily: 'Nunito',
      ),
      home: const HomeScreen(),
    );
  }
}
