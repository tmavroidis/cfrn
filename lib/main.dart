/// The entry point for the CFRN Web Radio application.
///
/// This file initializes the application, configures global audio settings,
/// and sets up the window management for desktop platforms.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/radio_page.dart';

/// The main entry point of the application.
///
/// Performs necessary initializations for Flutter, global audio context,
/// and window management if running on a desktop platform.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure global audio context for background playback.
  // This ensures that the audio continues to play when the app is in the background
  // and handles audio focus correctly on Android and iOS.
  await AudioPlayer.global.setAudioContext(AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: {
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
  ));

  // Platform-specific initialization for desktop systems.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 800),
      minimumSize: Size(300, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

/// The root widget of the CFRN Web Radio application.
///
/// Configures the overall theme of the app and sets [RadioPage] as the home screen.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web Radio',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Colors.brown[100],
      ),
      home: const RadioPage(),
    );
  }
}
