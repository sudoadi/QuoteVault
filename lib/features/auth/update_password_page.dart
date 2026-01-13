import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart'; // Ensure supabase client is accessible
import 'funky_widgets.dart'; // Reuse your style

class UpdatePasswordPage extends StatefulWidget {
  const UpdatePasswordPage({super.key});

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (_passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // User is already logged in via the email link, so we just update
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully! 🚀")),
        );
        // Go back to home/profile
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Set New Password")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
                "NEW BEGINNINGS",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)
            ),
            const SizedBox(height: 20),
            FunkyTextField(
              label: "New Password",
              controller: _passwordController,
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : FunkyButton(
              text: "UPDATE PASSWORD",
              color: const Color(0xFF4ECDC4),
              onPressed: _updatePassword,
            ),
          ],
        ),
      ),
    );
  }
}