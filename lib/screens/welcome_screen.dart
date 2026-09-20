// lib/screens/welcome_screen.dart
//
// App entry screen — displays TuturEdu branding/logo with options to
// Log In or Sign Up, followed by an inline "About Pusat Tuisyen Arena
// Matriks" section and a social-links footer on the same scrollable page
// (no separate About route - see CLAUDE.md for why).

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/office_hours.dart';
import 'login_screen.dart';
import 'register_screen.dart';

const _kInkDark = Color(0xFF16283D);
const _kInkMuted = Color(0xFF64748B);

// These 2 constants above are the FIXED colors used inside the "About the
// Centre" navy panel (solid dark bg + white text, always the same
// regardless of theme - a deliberate highlight block, not scaffold-driven).
// Everywhere else on this page sits on the plain Scaffold background, which
// DOES follow the account's Light/Dark/System choice (see main.dart) - so
// text/border colors there must come from these theme-aware helpers
// instead, or they'd stay dark-on-dark (or light-on-light) if the system
// theme flips.
Color _inkDark(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge?.color ?? _kInkDark;
Color _inkMuted(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.color ?? _kInkMuted;
Color _borderColor(BuildContext context) => Theme.of(context).dividerColor;

class _Offering {
  final IconData icon;
  final String title;
  final String description;

  const _Offering({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _SocialLink {
  final FaIconData icon;
  final String label;
  final String url;

  const _SocialLink({
    required this.icon,
    required this.label,
    required this.url,
  });
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const List<_Offering> _offerings = [
    _Offering(
      icon: Icons.groups_outlined,
      title: 'Small, focused classes',
      description:
          'Class sizes kept manageable so every student gets real attention, '
          'not just a seat in a crowd.',
    ),
    _Offering(
      icon: Icons.menu_book_outlined,
      title: 'Subjects across levels',
      description:
          'Core and elective subjects covering primary through secondary '
          'levels, taught by tutors who know the syllabus inside out.',
    ),
    _Offering(
      icon: Icons.trending_up_outlined,
      title: 'Progress that\'s tracked, not guessed',
      description:
          'Attendance, grades, and performance trends are recorded every '
          'term, so both the centre and parents can see how a student is '
          'actually doing.',
    ),
    _Offering(
      icon: Icons.forum_outlined,
      title: 'One conversation space',
      description:
          'TuturEdu keeps students, parents, and tutors talking in one '
          'place, inside clear working hours - not scattered across '
          'personal phone numbers.',
    ),
  ];

  static const List<_SocialLink> _socialLinks = [
    _SocialLink(
      icon: FontAwesomeIcons.facebookF,
      label: 'Facebook',
      url: 'https://www.facebook.com/pusattuisyenarenamatriks/',
    ),
    _SocialLink(
      icon: FontAwesomeIcons.instagram,
      label: 'Instagram',
      url: 'https://www.instagram.com/arena_matriks/reels/',
    ),
    _SocialLink(
      icon: FontAwesomeIcons.tiktok,
      label: 'TikTok',
      url: 'https://www.tiktok.com/@arenamatriks',
    ),
  ];

  Future<void> _openSocialLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: quick-access Log In / Sign Up links, in addition to
            // the full-size buttons further down - lets a returning user
            // skip straight to Log In without scrolling/reading the rest.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 20, 0),
              child: Row(
                children: [
                  Text(
                    'TuturEdu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: _inkDark(context),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _inkMuted(context),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _inkDark(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Image.asset(
                                  'assets/images/tuturedu_logo_trimmed.png',
                                  width: double.infinity,
                                  height: 96,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'The chat platform built for\nPusat Tuisyen Arena Matriks',
                                  style: TextStyle(
                                    fontSize: 30,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    color: _inkDark(context),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'One organised space to connect students, '
                                  'teachers, and parents — inside clear '
                                  'working hours, with nothing lost in a '
                                  'group chat.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: _inkMuted(context),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterScreen(),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _kInkDark,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text(
                                            'Sign Up',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginScreen(),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _inkDark(context),
                                            side: BorderSide(
                                              color: _borderColor(context),
                                              width: 1.4,
                                            ),
                                            backgroundColor: Theme.of(
                                              context,
                                            ).cardColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text(
                                            'Log In',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 56),

                          // About Pusat Tuisyen Arena Matriks - a solid
                          // ink-navy panel (no gradient), continuing right
                          // on this page rather than a separate route.
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
                            color: _kInkDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        'assets/images/arena_matrix_logo.png',
                                        height: 40,
                                        width: 48,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  height: 40,
                                                  width: 48,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.1),
                                                  child: const Icon(
                                                    Icons.school,
                                                    color: Colors.white70,
                                                    size: 20,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'ABOUT THE CENTRE',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.4,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Pusat Tuisyen Arena Matriks',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Built around one idea: learning works '
                                  'best when students, tutors, and parents '
                                  'are genuinely connected. Every class runs '
                                  'with that in mind — structured lessons, '
                                  'tutors who follow up on progress, and a '
                                  'clear line of communication home.\n\n'
                                  'TuturEdu is the centre\'s official chat '
                                  'platform, carrying that connection '
                                  'online: one safe space for students, '
                                  'parents, and tutors to talk, in line '
                                  'with the centre\'s working hours.',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.65,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_outlined,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'OPERATING HOURS',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1,
                                                color: Colors.white54,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              OfficeHours.officeHourText(),
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // What We Offer - flat list, thin dividers, no
                          // card/shadow soup.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
                            child: Text(
                              'WHAT WE OFFER',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: _inkMuted(
                                  context,
                                ).withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                            child: Column(
                              children: [
                                for (var i = 0; i < _offerings.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      color: _borderColor(context),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _offerings[i].icon,
                                          color: _inkDark(context),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _offerings[i].title,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: _inkDark(context),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _offerings[i].description,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  height: 1.5,
                                                  color: _inkMuted(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Footer: social links + copyright.
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: _borderColor(context),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: _socialLinks
                                      .map(
                                        (s) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: _SocialButton(
                                            link: s,
                                            onTap: () =>
                                                _openSocialLink(context, s.url),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '© ${DateTime.now().year} Pusat Tuisyen Arena Matriks',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _inkMuted(
                                      context,
                                    ).withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final _SocialLink link;
  final VoidCallback onTap;

  const _SocialButton({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: link.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _borderColor(context), width: 1.4),
          ),
          child: FaIcon(link.icon, color: _inkDark(context), size: 16),
        ),
      ),
    );
  }
}
