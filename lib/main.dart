import 'package:flutter/material.dart';
import 'package:taara/theme/app_theme.dart';
import 'package:taara/screens/splash_screen.dart';
import 'package:taara/screens/home_screen.dart';
import 'package:taara/screens/scan_screen.dart';
import 'package:taara/screens/result_screen.dart';
import 'package:taara/screens/guide_screen.dart';
import 'package:taara/screens/voice_screen.dart';
import 'package:taara/screens/auth_screen.dart';
import 'package:taara/screens/pros_screen.dart';
import 'package:taara/screens/my_jobs_screen.dart';
import 'package:taara/screens/job_chat_screen.dart';
import 'package:taara/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
  runApp(const TaaraApp());
}

class TaaraApp extends StatelessWidget {
  const TaaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taara',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const ScanScreen(),
        '/voice': (context) => const VoiceScreen(),
        '/result': (context) => const ResultScreen(),
        '/guide': (context) => const GuideScreen(),
        '/auth': (context) => const AuthScreen(),
        '/pros': (context) => const ProsScreen(),
        '/my-jobs': (context) => const MyJobsScreen(),
        '/chat': (context) => const JobChatScreen(),
      },
    );
  }
}