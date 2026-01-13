import 'package:flutter/material.dart';
import 'package:quotevault/features/auth/welcome_login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../landing/landing_page.dart';
import '../auth/update_password_page.dart'; // Import Update Page
import '../../main.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // If the event is specifically password recovery, show that page
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const UpdatePasswordPage();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const WelcomeLoginPage();
        } else {
          return const LandingPage();
        }
      },
    );
  }
}