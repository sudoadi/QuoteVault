import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import 'funky_widgets.dart';
import 'welcome_signup.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State
  File? _imageFile;
  bool _isLoading = false;
  bool _isUsernameAvailable = true;
  bool _isCheckingUsername = false;

  // === NEW: REAL UPLOAD STATE ===
  bool _isImageUploading = false;
  String? _uploadedAvatarUrl; // Stores the URL after pre-upload

  Timer? _debounce;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() => _isCheckingUsername = false);
        return;
      }

      try {
        final data = await supabase
            .from('profiles')
            .select('username')
            .eq('username', username)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _isUsernameAvailable = data == null;
            _isCheckingUsername = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isCheckingUsername = false);
      }
    });
  }

  // === NEW: REAL BACKGROUND UPLOAD ===
  Future<void> _uploadRealImage(File file) async {
    setState(() {
      _isImageUploading = true;
      _uploadedAvatarUrl = null; // Reset previous url
    });

    try {
      // 1. Generate a temp filename (since we don't have User ID yet)
      final fileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Perform the REAL upload
      await supabase.storage.from('avatars').upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // 3. Get the URL immediately
      final url = supabase.storage.from('avatars').getPublicUrl(fileName);

      if (mounted) {
        setState(() {
          _uploadedAvatarUrl = url;
          _isImageUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImageUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _imageFile = file;
      });
      // Trigger the real network upload immediately
      _uploadRealImage(file);
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _uploadedAvatarUrl = null;
      _isImageUploading = false;
    });
  }

  void _initiateSignUp() {
    if (_fullNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields!')),
      );
      return;
    }

    if (!_isUsernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username is taken!')),
      );
      return;
    }

    // === CHECK REAL STATUS ===
    if (_isImageUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait! Photo is actually uploading... 📡'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final confirmPassController = TextEditingController();
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "CONFIRM PASSWORD",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.0)
                  ),
                  const SizedBox(height: 10),
                  const Text("Just to be safe.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  FunkyTextField(
                    label: "Retype Password",
                    controller: confirmPassController,
                    icon: Icons.lock_reset,
                    obscureText: true,
                  ),

                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: FunkyButton(
                          text: "CANCEL",
                          color: Colors.grey.shade300,
                          textColor: Colors.black54,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: FunkyButton(
                          text: "GO!",
                          color: const Color(0xFF4ECDC4),
                          onPressed: () {
                            if (confirmPassController.text == _passwordController.text) {
                              Navigator.pop(ctx);
                              _processSignUp();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Passwords do not match! ❌'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }
    );
  }

  Future<void> _processSignUp() async {
    setState(() => _isLoading = true);
    try {
      // 1. Create Auth User
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'username': _usernameController.text.trim(),
          'full_name': _fullNameController.text.trim(),
        },
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw const AuthException("Signup failed");

      // 2. Link the ALREADY UPLOADED image
      // (We skip the upload step here because it happened in background)
      if (_uploadedAvatarUrl != null) {
        await supabase.from('profiles').update({
          'avatar_url': _uploadedAvatarUrl,
        }).eq('id', userId);
      }

      // 3. Navigate
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomeSignupPage(
              fullName: _fullNameController.text.trim(),
              username: _usernameController.text.trim(),
              imageFile: _imageFile,
            ),
          ),
        );
      }

    } on AuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dateStr = DateFormat('MMM-d-yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFFF6B6B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 30),
        title: const Text("New Agent Registration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // === ID CARD ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(6, 6), blurRadius: 0)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.qr_code_2, size: 40),
                        Text("QUOTEVAULT ID", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // === PROFILE PHOTO WITH REAL STATUS ===
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // INDETERMINATE SPINNER (Shows while network request is active)
                        if (_isImageUploading)
                          SizedBox(
                            width: 108,
                            height: 108,
                            child: const CircularProgressIndicator(
                              strokeWidth: 5,
                              color: Color(0xFF2ECC71),
                            ),
                          )
                        // SOLID RING (Shows when upload is done)
                        else if (_uploadedAvatarUrl != null)
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF2ECC71), width: 5)
                            ),
                          ),

                        // The Photo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                            color: Colors.grey[200],
                            image: _imageFile != null
                                ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _imageFile == null
                              ? const Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),

                        // Edit Buttons
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                ),
                              ),
                              if (_imageFile != null)
                                GestureDetector(
                                  onTap: _removeImage,
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 5),
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    ListenableBuilder(
                      listenable: _fullNameController,
                      builder: (context, _) => Text(
                        _fullNameController.text.isEmpty ? "YOUR NAME" : _fullNameController.text.toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 5),
                    ListenableBuilder(
                      listenable: _usernameController,
                      builder: (context, _) => Text(
                        _usernameController.text.isEmpty ? "@username" : "@${_usernameController.text.toLowerCase()}",
                        style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
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

              const SizedBox(height: 40),

              // === INPUT FIELDS ===
              FunkyTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  icon: Icons.badge_outlined
              ),
              const SizedBox(height: 15),

              Stack(
                alignment: Alignment.centerRight,
                children: [
                  FunkyTextField(
                      label: 'Username',
                      controller: _usernameController,
                      icon: Icons.alternate_email
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 15.0),
                    child: _isCheckingUsername
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : _usernameController.text.isNotEmpty
                        ? Icon(
                      _isUsernameAvailable ? Icons.check_circle : Icons.cancel,
                      color: _isUsernameAvailable ? Colors.green : Colors.red,
                    )
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 15),
              FunkyTextField(
                  label: 'Email',
                  controller: _emailController,
                  icon: Icons.mail_outline
              ),
              const SizedBox(height: 15),
              FunkyTextField(
                  label: 'Password',
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  obscureText: true
              ),
              const SizedBox(height: 40),

              _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : FunkyButton(
                text: "BLAST OFF 🚀",
                color: const Color(0xFF4ECDC4),
                onPressed: _initiateSignUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}