import 'dart:async';
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
import 'package:taara/services/realtime_service.dart';

/// Permet d'afficher une bannière de notification quel que soit l'écran ouvert.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();
final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
  RealtimeService.start();
  runApp(const TaaraApp());
}

class TaaraApp extends StatefulWidget {
  const TaaraApp({super.key});

  @override
  State<TaaraApp> createState() => _TaaraAppState();
}

class _TaaraAppState extends State<TaaraApp> {
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _notifSub = RealtimeService.notifications.listen(_showNotification);
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _showNotification(Map<String, dynamic> n) {
    final link = n['link'] as String?;
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n['title'] ?? 'Taara',
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(n['message'] ?? '',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
          action: link != null && link.startsWith('/jobs/')
              ? SnackBarAction(
                  label: 'VOIR',
                  textColor: AppTheme.primary,
                  onPressed: () =>
                      rootNavigatorKey.currentState?.pushNamed('/my-jobs'),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taara',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scaffoldMessengerKey: rootMessengerKey,
      navigatorKey: rootNavigatorKey,
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
