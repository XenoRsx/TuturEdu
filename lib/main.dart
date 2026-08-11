import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'utils/notification_sounds.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required to initialize Firebase when the app starts
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// Lets FirebaseMessaging.onMessage (see below) show a SnackBar for a push
// notification that arrives while the app is already open and focused -
// FCM only auto-displays a system notification when the app is
// backgrounded/closed, so this is the only way foreground pushes are ever
// seen. Not scoped to any single screen's context, so a global key.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Shared design language for the whole app, echoing welcome_screen's
// original palette so every screen feels like one product instead of a
// patchwork of default Material widgets.
const Color kBrandBlue = Color(0xFF2E86C1);
const Color kBrandGreen = Color(0xFF1B8E5A);
const Color kInkDark = Color(0xFF1B3B5F);
const Color kInkMuted = Color(0xFF6B7A8F);
const Color kAppBackground = Color(0xFFF6F9FC);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Best-effort: an unsupported browser/platform just never fires this.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            '${notification.title ?? ''}: ${notification.body ?? ''}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      // Best-effort - see notification_sounds.dart. Only for foreground
      // messages; background/system notifications get their sound from the
      // FCM payload itself (Android only, set server-side).
      playNotificationSoundForCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'TuturEdu',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kBrandBlue),
        scaffoldBackgroundColor: kAppBackground,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrandBlue, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 1,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
