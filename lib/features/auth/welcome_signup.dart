import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';
import 'welcome_login.dart'; // To navigate to loading screen

class WelcomeSignupPage extends StatefulWidget {
  final String fullName;
  final String username;
  final File? imageFile;

  const WelcomeSignupPage({
    super.key,
    required this.fullName,
    required this.username,
    this.imageFile,
  });

  @override
  State<WelcomeSignupPage> createState() => _WelcomeSignupPageState();
}

class _WelcomeSignupPageState extends State<WelcomeSignupPage> with TickerProviderStateMixin {
  late AnimationController _cardController;
  late AnimationController _stampController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _stampScaleAnimation;
  late Animation<double> _stampOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Card Slide Up Animation
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // Start below screen
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic));

    // 2. Stamp Zoom Animation
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _stampScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.8), weight: 80), // Zoom in fast
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 20), // Bounce back
    ]).animate(CurvedAnimation(parent: _stampController, curve: Curves.easeOut));

    _stampOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stampController, curve: const Interval(0.0, 0.5)),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Step 1: Slide Card Up
    await Future.delayed(const Duration(milliseconds: 300));
    await _cardController.forward();

    // Step 2: Stamp Effect
    await Future.delayed(const Duration(milliseconds: 200));
    _vibrateStamp();
    await _stampController.forward();

    // Step 3: Wait 1 second, then go to Welcome/Loading
    await Future.delayed(const Duration(seconds: 4)); // 1s wait + buffer
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeLoginPage()),
      );
    }
  }

  Future<void> _vibrateStamp() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100); // Sharp thud
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    _stampController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String dateStr = DateFormat('MMM-d-yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFFF6B6B),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // === THE SLIDING ID CARD ===
          SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(6, 6), blurRadius: 0)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.qr_code_2, size: 40),
                          Text("QUOTEVAULT ID", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w900, letterSpacing: 2)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                          color: Colors.grey[200],
                          image: widget.imageFile != null
                              ? DecorationImage(image: FileImage(widget.imageFile!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: widget.imageFile == null
                            ? const Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(height: 15),

                      Text(
                        widget.fullName.toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "@${widget.username.toLowerCase()}",
                        style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          "ISSUED: $dateStr",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // === THE STAMP OVERLAY ===
          AnimatedBuilder(
            animation: _stampController,
            builder: (context, child) {
              return Transform.scale(
                scale: _stampScaleAnimation.value,
                child: Opacity(
                  opacity: _stampOpacityAnimation.value,
                  child: Transform.rotate(
                    angle: -0.5, // Tilted stamp
                    child: Image.asset(
                      'assets/approved.png',
                      width: 250,
                      color: Colors.green.withOpacity(0.5), // Green ink look
                      colorBlendMode: BlendMode.modulate,
                      errorBuilder: (ctx, err, stack) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 5),
                            borderRadius: BorderRadius.circular(10)
                        ),
                        child: const Text("APPROVED", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                      ), // Fallback if image missing
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}