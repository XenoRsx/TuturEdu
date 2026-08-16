// lib/screens/welcome_screen.dart
//
// App entry screen — displays TuturEdu branding/logo with options to
// Log In or Sign Up.

import 'package:flutter/material.dart';
import 'about_arena_matriks_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4FAF7), Color(0xFFEAF3FB)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo. Uses the trimmed wordmark (tuturedu_logo.png has a
                // lot of blank canvas padding baked in - see
                // tuturedu_logo_trimmed.png, which crops to the tight
                // content bbox only) so it renders at a readable size in
                // this narrow column instead of shrinking to fit the
                // original banner's ~9.6:1 aspect ratio.
                Image.asset(
                  'assets/images/tuturedu_logo_trimmed.png',
                  width: double.infinity,
                  height: 130,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 36),

                const Text(
                  'Welcome to TuturEdu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3B5F),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'A single, organised space for tuition centres to\nconnect students, teachers, and parents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: Color(0xFF6B7A8F),
                  ),
                ),
                const SizedBox(height: 56),

                // Log In button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E86C1),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(
                        0xFF2E86C1,
                      ).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Sign Up button
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B8E5A),
                      side: const BorderSide(
                        color: Color(0xFF1B8E5A),
                        width: 1.5,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // About Pusat Tuisyen Arena Matriks
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AboutArenaMatriksScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'About Pusat Tuisyen Arena Matriks',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7A8F),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
