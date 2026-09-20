import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'utils/notification_sounds.dart';
import 'utils/theme_preference.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required to initialize Firebase when the app starts
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Web only: don't persist the session across page loads - a shared/public
  // browser shouldn't stay signed in the way a personal phone does (see
  // AuthGate, which auto-routes past login on mobile/desktop using whatever
  // Firebase Auth persisted). Default web persistence is LOCAL (survives
  // closing the tab/browser); NONE clears it as soon as the page reloads,
  // so the web build always lands back on WelcomeScreen needing a fresh
  // sign-in. Native platforms ignore setPersistence (no-op there).
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  }

  runApp(const MyApp());
}

// Lets FirebaseMessaging.onMessage (see below) show a SnackBar for a push
// notification that arrives while the app is already open and focused -
// FCM only auto-displays a system notification when the app is
// backgrounded/closed, so this is the only way foreground pushes are ever
// seen. Not scoped to any single screen's context, so a global key.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// The account's chosen theme (users/{uid}.themeMode - see
// settings_screen.dart and utils/theme_preference.dart), applied app-wide.
// A ValueNotifier (not Provider/Riverpod - the app has no state management
// package, and this is the only piece of truly global mutable state) so any
// widget could react to it if ever needed, though today only MyApp's own
// MaterialApp does. Defaults to "system" pre-login and while the account's
// preference is still loading.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.system,
);

// Shared design language for the whole app, echoing welcome_screen's
// original palette so every screen feels like one product instead of a
// patchwork of default Material widgets.
const Color kBrandBlue = Color(0xFF2E86C1);
const Color kBrandGreen = Color(0xFF1B8E5A);
const Color kInkDark = Color(0xFF1B3B5F);
const Color kInkMuted = Color(0xFF6B7A8F);

// Claymorphism tokens. The "clay" look comes from a soft, puffy surface
// whose fill color sits close to the page background (not a contrasting
// white card) - depth comes entirely from a dual-direction shadow (a dark
// "sunken" shadow on one side, a light "highlight" on the other), not from
// elevation or a border. Brand blue/green stay solid/saturated for buttons
// and icons per the chosen direction (soft pastel surfaces, accent color
// kept on interactive elements) - see CLAUDE.md.
const Color kClayBaseLight = Color(0xFFE7EEF7);
const Color kClaySurfaceLight = Color(0xFFEFF4FA);
const Color kClayShadowLight = Color(0xFFAEC0D6);
const Color kClayHighlightLight = Colors.white;

const Color kClayBaseDark = Color(0xFF232A38);
const Color kClaySurfaceDark = Color(0xFF2A3242);
const Color kClayShadowDark = Color(0xFF11151D);
const Color kClayHighlightDark = Color(0xFF3B4557);

/// The dual clay shadow (dark "sunken" + light "highlight") for a soft 3D
/// puffy surface - use on any Container/DecoratedBox that should read as a
/// clay card. `intensity` scales offset/blur (smaller for small chips like
/// IconTile, 1.0 for full cards).
List<BoxShadow> clayShadows(BuildContext context, {double intensity = 1}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final shadowColor = isDark ? kClayShadowDark : kClayShadowLight;
  final highlightColor = isDark ? kClayHighlightDark : kClayHighlightLight;
  return [
    BoxShadow(
      color: shadowColor.withValues(alpha: isDark ? 0.7 : 0.55),
      offset: Offset(5 * intensity, 5 * intensity),
      blurRadius: 14 * intensity,
    ),
    BoxShadow(
      color: highlightColor.withValues(alpha: isDark ? 0.4 : 0.9),
      offset: Offset(-5 * intensity, -5 * intensity),
      blurRadius: 14 * intensity,
    ),
  ];
}

// Shared spacing scale - use these instead of ad hoc SizedBox/padding
// values so gaps stay consistent across screens.
const double kSpaceXs = 4;
const double kSpaceSm = 8;
const double kSpaceMd = 16;
const double kSpaceLg = 24;
const double kSpaceXl = 32;

// Shared text style presets - reach for these before adding another one-off
// fontSize/fontWeight combination.
const TextStyle kTextTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: kInkDark,
);
const TextStyle kTextBody = TextStyle(fontSize: 14, color: kInkDark);
const TextStyle kTextCaption = TextStyle(fontSize: 12.5, color: kInkMuted);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _themeModeSub;

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

    // Applies the signed-in account's saved theme preference app-wide as
    // soon as it's known, not just while Settings happens to be open -
    // that's the whole point of it being an account setting rather than a
    // per-device one. Falls back to "system" pre-login and while signed
    // out, matching themeModeNotifier's initial value.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _themeModeSub?.cancel();
      if (user == null) {
        themeModeNotifier.value = ThemeMode.system;
        return;
      }
      _themeModeSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
            themeModeNotifier.value = themeModeFromString(
              doc.data()?['themeMode'] as String?,
            );
          });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _themeModeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        title: 'TuturEdu',
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: mode,
        home: const AuthGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? kClayBaseDark : kClayBaseLight;
    final cardBg = isDark ? kClaySurfaceDark : kClaySurfaceLight;
    final borderColor = isDark ? Colors.white12 : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kBrandBlue,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
      ),
      // Card's own `elevation`/shadow stays off - AppCard (lib/widgets/
      // app_card.dart) draws the actual clay dual-shadow itself, since
      // CardThemeData only supports a single flat Material shadow.
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: kBrandBlue, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
