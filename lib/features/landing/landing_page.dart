import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/animations/circular_reveal_route.dart';
import '../auth/login_page.dart';
import '../auth/signup_page.dart';
// Assuming funky_widgets is in auth folder. Adjust path if needed.
import '../auth/funky_widgets.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _animController;

  // Animations
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Video
    _videoController = VideoPlayerController.asset('assets/quotevault_landing.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.play();
        _videoController.setVolume(0);
        _videoController.setLooping(true); // Loop properly
      });

    // 2. Setup Animation Controller
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 3. Define Slide Up Animation (with a bounce/spring feel)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start below screen
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut, // Funky bounce effect
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: const Interval(0.4, 1.0, curve: Curves.easeIn))
    );

    // 4. Trigger animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget page, BuildContext buttonContext) {
    _videoController.pause();
    final RenderBox box = buttonContext.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(box.size.center(Offset.zero));

    Navigator.push(
      context,
      CircularRevealRoute(page: page, center: position),
    ).then((_) {
      _videoController.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // === LAYER 1: VIDEO BACKGROUND ===
          if (_videoController.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            ),

          // Overlay to make text readable
          Container(color: Colors.black.withOpacity(0.3)),

          // === LAYER 2: FUNKY BOTTOM SHEET ===
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                padding: const EdgeInsets.fromLTRB(30, 40, 30, 50),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1C40F), // The "Funky" Yellow
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  // Funky Border
                  border: Border(
                    top: BorderSide(color: Colors.black, width: 4),
                    left: BorderSide(color: Colors.black, width: 4),
                    right: BorderSide(color: Colors.black, width: 4),
                  ),
                  // Funky Hard Shadow (simulated with container below usually, but boxShadow works too)
                  boxShadow: [
                    BoxShadow(color: Colors.black, offset: Offset(0, -10), blurRadius: 0) // Negative offset for shadow "behind" going up? No, let's keep it clean inside.
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Decoration Line
                    Center(
                      child: Container(
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Subtitle
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Your personal vault for the world\'s greatest quotes. Capture, organize, and get inspired.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Buttons Row
                    Row(
                      children: [
                        // SIGN IN (Black)
                        Expanded(
                          child: Builder(builder: (ctx) {
                            return FunkyButton(
                              text: "SIGN IN",
                              color: Colors.black,
                              textColor: Colors.white,
                              onPressed: () => _navigateTo(const LoginPage(), ctx),
                            );
                          }),
                        ),
                        const SizedBox(width: 20),

                        // SIGN UP (White)
                        Expanded(
                          child: Builder(builder: (ctx) {
                            return FunkyButton(
                              text: "SIGN UP",
                              color: Colors.white,
                              textColor: Colors.black,
                              onPressed: () => _navigateTo(const SignUpPage(), ctx),
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}