import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/photo_store.dart';
import 'services/remote_config.dart';
import 'services/sound.dart';
import 'services/storage.dart';
import 'ui/home_screen.dart';
import 'ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Storage.init();
  // Quick: uses saved or built-in values, fetches new ones in the background.
  await RemoteConfigService.init();
  await PhotoStore.load();
  await Sound.init();
  Sound.startMusic();
  // Pause the music while the app is in the background.
  _lifecycle = AppLifecycleListener(onHide: Sound.stopMusic, onShow: Sound.applyMusicSetting);
  runApp(const BlazegridApp());
}

// ignore: unused_element
late final AppLifecycleListener _lifecycle;

class BlazegridApp extends StatelessWidget {
  const BlazegridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blazegrid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.leaf, brightness: Brightness.dark, surface: Palette.panel),
        scaffoldBackgroundColor: Palette.background,
        useMaterial3: true,
        fontFamily: 'Nunito',
      ),
      home: const HomeScreen(),
    );
  }
}
