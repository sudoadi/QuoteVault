import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../features/home/home_page.dart';

// === IMPORTS ===
import '../profile/profile_page.dart';
import '../landing/landing_page.dart'; // Kept as a safety fallback

class WelcomeLoginPage extends StatefulWidget {
  const WelcomeLoginPage({super.key});

  @override
  State<WelcomeLoginPage> createState() => _WelcomeLoginPageState();
}

class _WelcomeLoginPageState extends State<WelcomeLoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _displayText = "Loading...";
  String _username = "Traveller";
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();

    // 1. Setup Animation (3 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // 2. Start Everything
    _controller.forward();
    _loadUserProfile();

    // 3. Update Text halfway through (at 70% progress)
    _controller.addListener(() {
      if (_controller.value > 0.7 && _displayText == "Loading...") {
        setState(() {
          _displayText = "Welcome,\n$_username!";
        });
      }
    });

    // 4. Navigate when finished
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Small buffer to ensure user reads the text
        Future.delayed(const Duration(milliseconds: 500), () {
          _goToHome();
        });
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;

    // Safety Check: If we somehow got here without a user, bail out.
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LandingPage())
        );
      }
      return;
    }

    try {
      // Fetch Username & Avatar
      final data = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted && data != null) {
        setState(() {
          if (data['username'] != null) {
            _username = data['username'].toString().toUpperCase();
          }
          if (data['avatar_url'] != null) {
            _avatarUrl = data['avatar_url'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  void _goToHome() {
    if (!mounted) return;
    // Swap ProfilePage() with HomePage()
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2ECC71), // Success Green
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // === ROCKET ANIMATION STACK ===
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Avatar (Center)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: ClipOval(
                      child: _avatarUrl != null
                          ? Image.network(
                        _avatarUrl!,
                        fit: BoxFit.cover,
                        // Simple error/loading handlers
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.person, size: 60, color: Colors.grey),
                      )
                          : const Icon(Icons.person, size: 60, color: Colors.grey),
                    ),
                  ),

                  // 2. Yellow Trail
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: TrailPainter(_controller.value),
                        );
                      },
                    ),
                  ),

                  // 3. Rocket
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // Orbit Logic
                      final double angle = (_controller.value * 2 * pi) - (pi / 2);
                      final double radius = 80.0;

                      final double x = radius * cos(angle);
                      final double y = radius * sin(angle);

                      return Transform.translate(
                        offset: Offset(x, y),
                        child: Transform.rotate(
                          angle: angle + (pi / 2),
                          child: Image.asset(
                            'assets/rocket_flat.png',
                            width: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // === TEXT DISPLAY ===
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(animation),
                    child: child
                ));
              },
              child: Text(
                _displayText,
                key: ValueKey<String>(_displayText),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === TRAIL PAINTER ===
class TrailPainter extends CustomPainter {
  final double progress;
  TrailPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    // Yellow Trail
    final trailPaint = Paint()
      ..color = const Color(0xFFF1C40F)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;

    // Draw Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      trailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TrailPainter oldDelegate) => oldDelegate.progress != progress;
}