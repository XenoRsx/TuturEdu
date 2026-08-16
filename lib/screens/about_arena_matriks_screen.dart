// lib/screens/about_arena_matriks_screen.dart
//
// Static "About" page telling the story of Pusat Tuisyen Arena Matriks, the
// tuition centre TuturEdu is built for. Reachable pre-login (from
// WelcomeScreen and LoginScreen) so it doesn't touch Firestore/Auth at all -
// keeps it simple and avoids needing a public-read security rule just for
// a decorative page.

import 'package:flutter/material.dart';
import '../main.dart' show kBrandBlue, kBrandGreen, kInkDark, kInkMuted;
import '../utils/office_hours.dart';

class AboutArenaMatriksScreen extends StatelessWidget {
  const AboutArenaMatriksScreen({super.key});

  static const List<_Offering> _offerings = [
    _Offering(
      icon: Icons.groups_outlined,
      accent: kBrandBlue,
      title: 'Small, focused classes',
      description:
          'Class sizes kept manageable so every student gets real attention, '
          'not just a seat in a crowd.',
    ),
    _Offering(
      icon: Icons.menu_book_outlined,
      accent: kBrandGreen,
      title: 'Subjects across levels',
      description:
          'Core and elective subjects covering primary through secondary '
          'levels, taught by tutors who know the syllabus inside out.',
    ),
    _Offering(
      icon: Icons.trending_up_outlined,
      accent: kBrandBlue,
      title: 'Progress that\'s tracked, not guessed',
      description:
          'Attendance, grades, and performance trends are recorded every '
          'term, so both the centre and parents can see how a student is '
          'actually doing.',
    ),
    _Offering(
      icon: Icons.forum_outlined,
      accent: kBrandGreen,
      title: 'One conversation space',
      description:
          'TuturEdu keeps students, parents, and tutors talking in one '
          'place, inside clear working hours - not scattered across '
          'personal phone numbers.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(child: _HeroHeader()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _StoryCard(),
                const SizedBox(height: 32),

                const _SectionHeading(
                  icon: Icons.stars_rounded,
                  text: 'What We Offer',
                ),
                const SizedBox(height: 14),
                ..._offerings.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OfferingTile(offering: o),
                  ),
                ),
                const SizedBox(height: 20),

                const _SectionHeading(
                  icon: Icons.schedule_rounded,
                  text: 'Operating Hours',
                ),
                const SizedBox(height: 14),
                const _OperatingHoursBanner(),
                const SizedBox(height: 36),

                const _PoweredByFooter(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// Gradient banner: back button, logo in a white halo, name, tagline pill.
class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBrandBlue, Color(0xFF1FA97A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/arena_matrix_logo.png',
                height: 108,
                width: 132,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  height: 108,
                  width: 132,
                  child: Icon(
                    Icons.school,
                    size: 44,
                    color: kBrandBlue.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pusat Tuisyen\nArena Matriks',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'LEARN  •  TEACH  •  INSPIRE',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 108,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kBrandBlue, kBrandGreen],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Pusat Tuisyen Arena Matriks is a tuition centre built around '
              'one idea: learning works best when students, tutors, and '
              'parents are genuinely connected. Every class is run with '
              'that in mind - structured lessons, tutors who follow up on '
              'progress, and a clear line of communication home so nothing '
              'falls through the cracks.\n\n'
              'TuturEdu is the centre\'s official chat platform, built to '
              'carry that connection online: one safe space for students, '
              'parents, and tutors to talk, in line with the centre\'s '
              'working hours.',
              style: TextStyle(fontSize: 14, height: 1.65, color: kInkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionHeading({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kBrandBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: kBrandBlue),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: kInkDark,
          ),
        ),
      ],
    );
  }
}

class _OperatingHoursBanner extends StatelessWidget {
  const _OperatingHoursBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            kBrandBlue.withValues(alpha: 0.08),
            kBrandGreen.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBrandBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.schedule_outlined,
              color: kBrandBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We\'re open',
                  style: TextStyle(fontSize: 12.5, color: kInkMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  OfficeHours.officeHourText(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: kInkDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PoweredByFooter extends StatelessWidget {
  const _PoweredByFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            height: 1,
            width: 60,
            color: kInkMuted.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 18),
          Text(
            'Chat platform powered by',
            style: TextStyle(
              fontSize: 11.5,
              color: kInkMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'TuturEdu',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kBrandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Offering {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;

  const _Offering({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
  });
}

class _OfferingTile extends StatelessWidget {
  final _Offering offering;
  const _OfferingTile({required this.offering});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: offering.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(offering.icon, color: offering.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offering.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: kInkDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offering.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: kInkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
