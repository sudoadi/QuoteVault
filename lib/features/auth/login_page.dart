import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import '../../main.dart';
import 'signup_page.dart';
import 'funky_widgets.dart';
import 'welcome_login.dart';
import '../../core/animations/circular_reveal_route.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final GlobalKey _rocketPlaceholderKey = GlobalKey();

  late AnimationController _launchController;
  late AnimationController _shakeController;
  late AnimationController _successController;
  late AnimationController _crashController;
  late AnimationController _rippleController;

  String _buttonText = "Let me in!";
  String _rocketErrorText = "";
  bool _isLaunching = false;
  bool _isSuccessSequence = false;
  bool _hasCrashed = false;
  bool _isDragging = false;

  Offset? _startPos;
  Offset _rocketPos = Offset.zero;
  double _rocketScale = 1.0;

  @override
  void initState() {
    super.initState();
    _launchController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..repeat(reverse: true);
    _successController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _crashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

    // === SHOW AUTOFILL POPUP ON LOAD ===
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAutofillDialog();
    });
  }

  @override
  void dispose() {
    _launchController.dispose();
    _shakeController.dispose();
    _successController.dispose();
    _crashController.dispose();
    _rippleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // === NEW: AUTOFILL DIALOG ===
  void _showAutofillDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black, width: 3),
          ),
          title: const Text(
            "TEST CREDENTIALS",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Use these for testing:"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black),
                ),
                child: const Column(
                  children: [
                    Text("User: brewapps@mail.com", style: TextStyle(fontFamily: 'monospace')),
                    Text("Pass: password123", style: TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CLOSE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _emailController.text = "brewapps@mail.com";
                      _passwordController.text = "password123";
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1C40F), // Yellow
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    child: const Text("AUTOFILL", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  // === VIBRATION HELPERS ===

  Future<void> _vibrateLaunch() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 10, 20, 10, 20, 10, 20, 10]);
    }
  }

  Future<void> _vibrateSuccess() async {
    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      Vibration.vibrate(
        duration: 1000,
        pattern: [0, 200, 0, 400, 0, 200],
        intensities: [0, 64, 0, 255, 0, 64],
      );
    } else {
      Vibration.vibrate(duration: 500);
    }
  }

  Future<void> _vibrateCrash() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 50, 100, 50, 100, 50]);
    }
  }

  Future<void> _vibrateSnap() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 20);
    }
  }

  // ==========================

  void _startLaunch() {
    FocusManager.instance.primaryFocus?.unfocus();
    _vibrateLaunch();

    final RenderBox box = _rocketPlaceholderKey.currentContext!.findRenderObject() as RenderBox;
    final Size screenSize = MediaQuery.of(context).size;

    setState(() {
      _startPos = box.localToGlobal(Offset.zero);
      _rocketPos = _startPos!;
      _isLaunching = true;
      _hasCrashed = false;
      _rocketErrorText = "";
      _buttonText = "LIFT OFF! 🚀";
    });

    final Animation<double> launchCurve = CurvedAnimation(parent: _launchController, curve: Curves.easeInExpo);

    _launchController.forward(from: 0.0);
    _launchController.addListener(() {
      if (_isSuccessSequence || _hasCrashed) return;

      final t = launchCurve.value;

      final double targetX = (screenSize.width / 2) - 30;
      final double targetY = (screenSize.height / 2) - 30;
      final Offset centerScreen = Offset(targetX, targetY);

      final Offset currentPos = Offset.lerp(_startPos!, centerScreen, t)!;
      final double currentScale = 1.0 + (t * 12.0);

      setState(() {
        _rocketPos = currentPos;
        _rocketScale = currentScale;
      });
    });

    _performLogin();
  }

  Future<void> _performLogin() async {
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (_launchController.value < 0.5) {
        await Future.delayed(const Duration(seconds: 1));
      }
      _triggerSuccess();

    } on AuthException catch (_) {
      if (_launchController.value < 0.5) await Future.delayed(const Duration(seconds: 1));
      _triggerCrash("BAD AUTH");
    } catch (_) {
      _triggerCrash("ERROR");
    }
  }

  void _triggerSuccess() async {
    _vibrateSuccess();

    setState(() {
      _isSuccessSequence = true;
      _buttonText = "WELCOME";
    });

    final Size screenSize = MediaQuery.of(context).size;
    final Offset startPos = _rocketPos;
    final double startScale = _rocketScale;
    final Offset notchPos = Offset(screenSize.width / 2 - 30, 40);
    const double targetScale = 0.8;

    await _successController.animateTo(1.0, curve: Curves.easeInOut);

    final int steps = 20;
    for(int i=0; i<=steps; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      double t = Curves.easeInOut.transform(i/steps);
      setState(() {
        _rocketPos = Offset.lerp(startPos, notchPos, t)!;
        _rocketScale = (startScale * (1-t)) + (targetScale * t);
      });
    }

    if (mounted) {
      Navigator.push(
        context,
        CircularRevealRoute(
            page: const WelcomeLoginPage(),
            center: notchPos + const Offset(30, 30)
        ),
      );
    }
  }

  void _triggerCrash(String errorMsg) {
    _vibrateCrash();

    _launchController.stop();
    final Size size = MediaQuery.of(context).size;
    final Random rng = Random();

    final double targetY = size.height - 150 - rng.nextInt(100).toDouble();
    final double targetX = 30 + rng.nextInt((size.width - 100).toInt()).toDouble();

    setState(() {
      _hasCrashed = true;
      _rocketErrorText = errorMsg;
      _buttonText = "CRASHED! RESET?";
    });

    final Animation<double> curve = CurvedAnimation(parent: _crashController, curve: Curves.bounceOut);
    final Offset startFallPos = _rocketPos;
    final Offset endFallPos = Offset(targetX, targetY);
    final double startScale = _rocketScale;
    final double endScale = 1.5;

    _crashController.addListener(() {
      setState(() {
        _rocketPos = Offset.lerp(startFallPos, endFallPos, curve.value)!;
        _rocketScale = (startScale * (1-curve.value)) + (endScale * curve.value);
      });
    });

    _crashController.forward(from: 0.0);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_hasCrashed) return;
    setState(() {
      _isDragging = true;
      _rocketPos += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_hasCrashed) return;

    final RenderBox? boxRender = _rocketPlaceholderKey.currentContext?.findRenderObject() as RenderBox?;

    if (boxRender != null) {
      final Offset boxPos = boxRender.localToGlobal(Offset.zero);
      final Size boxSize = boxRender.size;

      // Box Rectangle (Expanded by 20px)
      final Rect boxRect = Rect.fromLTWH(
          boxPos.dx - 20,
          boxPos.dy - 20,
          boxSize.width + 40,
          boxSize.height + 40
      );

      // Rocket Rectangle (Visual Size)
      final double visualSize = 60.0 * 1.5;
      final Rect rocketRect = Rect.fromLTWH(
          _rocketPos.dx,
          _rocketPos.dy,
          visualSize,
          visualSize
      );

      // Check Overlap
      if (boxRect.overlaps(rocketRect)) {
        _vibrateSnap();

        setState(() {
          _isLaunching = false;
          _isSuccessSequence = false;
          _hasCrashed = false;
          _isDragging = false;
          _buttonText = "Let me in!";
          _launchController.reset();
          _crashController.reset();
          _successController.reset();
        });
        return;
      }
    }

    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF8E44AD),
      body: Stack(
        children: [
          // LAYER 1: SPEED LINES
          if (_isLaunching && !_hasCrashed && !_isSuccessSequence)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _launchController,
                builder: (context, child) {
                  return CustomPaint(painter: SpeedLinesPainter(_launchController.value));
                },
              ),
            ),

          // LAYER 2: THE UI FORM
          AnimatedBuilder(
            animation: _launchController,
            builder: (context, child) {
              double translationY = _launchController.value * size.height;
              double opacity = (1.0 - _launchController.value * 2).clamp(0.0, 1.0);

              if (_hasCrashed) {
                translationY = 0;
                opacity = 1.0;
              }

              return Transform.translate(
                offset: Offset(0, translationY),
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.rotate(
                      angle: -0.1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1C40F),
                          border: Border.all(width: 4),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
                        ),
                        child: const Text('QUOTE\nVAULT', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                      ),
                    ),
                    const SizedBox(height: 50),
                    FunkyTextField(label: 'Email', controller: _emailController, icon: Icons.alternate_email),
                    const SizedBox(height: 20),
                    FunkyTextField(label: 'Password', controller: _passwordController, icon: Icons.lock, obscureText: true),
                    const SizedBox(height: 40),

                    Row(
                      children: [
                        // BOX + RIPPLE
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (_hasCrashed)
                              AnimatedBuilder(
                                animation: _rippleController,
                                builder: (context, child) {
                                  return CustomPaint(
                                    painter: RipplePainter(_rippleController.value),
                                    size: const Size(120, 120),
                                  );
                                },
                              ),

                            Container(
                              key: _rocketPlaceholderKey,
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                    color: _isDragging ? Colors.yellow : Colors.white,
                                    width: _isDragging ? 5 : 3
                                ),
                              ),
                              child: !_isLaunching
                                  ? Center(child: Image.asset('assets/rocket.png', width: 35))
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLaunching ? null : _startLaunch,
                            child: FunkyButton(
                              text: _buttonText,
                              color: _hasCrashed ? Colors.red : const Color(0xFF2ECC71),
                              onPressed: _isLaunching ? () {} : _startLaunch,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    if (!_isLaunching)
                      Builder(
                          builder: (buttonContext) {
                            return GestureDetector(
                              onTap: () {
                                final RenderBox box = buttonContext.findRenderObject() as RenderBox;
                                final Offset position = box.localToGlobal(box.size.center(Offset.zero));
                                Navigator.push(
                                  context,
                                  CircularRevealRoute(page: const SignUpPage(), center: position),
                                );
                              },
                              child: const FunkyButton(
                                text: "CREATE ACCOUNT",
                                color: Color(0xFF4ECDC4),
                                textColor: Colors.black,
                                onPressed: null,
                              ),
                            );
                          }
                      ),
                  ],
                ),
              ),
            ),
          ),

          // LAYER 3: ROCKET
          if (_isLaunching && _startPos != null)
            Positioned(
              left: _rocketPos.dx,
              top: _rocketPos.dy,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    double offsetX = 0;
                    if (!_hasCrashed && !_isSuccessSequence && !_isDragging) {
                      offsetX = sin(_shakeController.value * pi * 8) * 2;
                    }

                    return Transform.translate(
                      offset: Offset(offsetX, 0),
                      child: Transform.scale(
                        scale: _rocketScale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/rocket.png',
                              width: 60,
                              color: _hasCrashed ? Colors.red : null,
                              colorBlendMode: _hasCrashed ? BlendMode.srcIn : null,
                            ),
                            if (_rocketErrorText.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                color: Colors.black,
                                child: Text(_rocketErrorText, style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 10)),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // LAYER 4: INSTRUCTION TEXT
          if (_hasCrashed && !_isDragging)
            Positioned(
              left: 0,
              right: 0,
              bottom: 120,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.black,
                  child: const Text("DRAG WRECKAGE TO BOX", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// === PAINTERS (Unchanged) ===

class SpeedLinesPainter extends CustomPainter {
  final double intensity;
  SpeedLinesPainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity < 0.1) return;
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.3 * intensity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Random rng = Random();
    for (int i = 0; i < 20; i++) {
      final double x = rng.nextDouble() * size.width;
      final double length = 50 + (intensity * 200);
      final double yStart = (rng.nextDouble() * size.height) + (intensity * 1000) % size.height;
      canvas.drawLine(Offset(x, yStart), Offset(x, yStart - length), paint);
    }
  }
  @override
  bool shouldRepaint(covariant SpeedLinesPainter oldDelegate) => oldDelegate.intensity != intensity;
}

class RipplePainter extends CustomPainter {
  final double animationValue;
  RipplePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    paint.color = Colors.yellow.withOpacity(1.0 - animationValue);
    canvas.drawCircle(size.center(Offset.zero), (size.width / 2) * animationValue, paint);

    if (animationValue > 0.5) {
      double delayedValue = (animationValue - 0.5) * 2;
      paint.color = Colors.yellow.withOpacity(1.0 - delayedValue);
      canvas.drawCircle(size.center(Offset.zero), (size.width / 2) * delayedValue, paint);
    }

    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.yellow.withOpacity(0.3)
      ..strokeWidth = 2;
    canvas.drawCircle(size.center(Offset.zero), 40, basePaint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}