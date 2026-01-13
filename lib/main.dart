import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

// === IMPORTS ===
import 'features/auth/welcome_login.dart';
import 'features/landing/landing_page.dart';
import 'features/auth/update_password_page.dart';
import 'features/profile/public_profile_page.dart';
import 'utils/circular_reveal_transition.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool isPasswordRecovery = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === DISABLE RED SCREEN OF DEATH ===
  // This hides layout overflow errors from the user's screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const SizedBox();
  };

  await Supabase.initialize(
    url: 'https://ehsyawhjbydmwhsyuqpf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoc3lhd2hqYnlkbXdoc3l1cXBmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNDc1NDcsImV4cCI6MjA4MzgyMzU0N30.fe1NlAlRTyNql9oMsP0rC3awZgPEo1L-b1VQW-MHl0k',
  );

  supabase.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      isPasswordRecovery = true;
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const UpdatePasswordPage()),
            (route) => false,
      );
    }
  });

  runApp(const QuoteVaultApp());
}

final supabase = Supabase.instance.client;

class QuoteVaultApp extends StatefulWidget {
  const QuoteVaultApp({super.key});

  @override
  State<QuoteVaultApp> createState() => _QuoteVaultAppState();
}

class _QuoteVaultAppState extends State<QuoteVaultApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    final appLink = await _appLinks.getInitialLink();
    if (appLink != null) _handleDeepLink(appLink);
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) => _handleDeepLink(uri));
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'signup') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (context) => const LandingPage()));
    } else if (uri.host == 'welcome') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (context) => const WelcomeLoginPage()));
    } else if (uri.host == 'reset-password') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (context) => const UpdatePasswordPage()));
    } else if (uri.host == 'profile' && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'id') {
        final username = uri.pathSegments[1];
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (context) => PublicProfilePage(username: username)));
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuoteVault',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CircularRevealPageTransitionsBuilder(),
            TargetPlatform.iOS: CircularRevealPageTransitionsBuilder(),
          },
        ),
      ),
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            RevealData.lastTap = event.position;
          },
          child: child,
        );
      },
      home: const CheckSessionPage(),
    );
  }
}

class CheckSessionPage extends StatefulWidget {
  const CheckSessionPage({super.key});

  @override
  State<CheckSessionPage> createState() => _CheckSessionPageState();
}

class _CheckSessionPageState extends State<CheckSessionPage> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (isPasswordRecovery) return;
    final session = supabase.auth.currentSession;
    if (mounted) {
      if (session != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeLoginPage()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LandingPage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.black);
  }
}