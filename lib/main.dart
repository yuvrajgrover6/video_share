import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:video_share/firebase_options.dart';
import 'package:video_share/views/hompage_view.dart';
import 'package:video_share/views/video_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Share',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: VideoScreen(),
    );
  }
}
