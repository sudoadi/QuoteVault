import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../managers/app_settings.dart';
import '../../managers/notification_manager.dart';
import '../landing/landing_page.dart';
import '../auth/funky_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  // Data State
  String _fullName = "Loading...";
  String _username = "Loading...";
  String _email = "Loading...";
  String? _avatarUrl;
  String _joinedDate = "";
  bool _isLoading = true;
  bool _isUploading = false;

  // Settings State
  bool _isDarkMode = false;
  int _themeColorIndex = 0;
  double _uiFontSize = 1.0;
  double _quoteFontSize = 1.0;

  // Notification State
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  // Animation State
  late AnimationController _flipController;
  late Animation<double> _frontRotation;
  late Animation<double> _backRotation;
  bool _isFlipped = false;

  final ImagePicker _picker = ImagePicker();

  final List<Color> _themeColors = [
    const Color(0xFF4ECDC4), const Color(0xFFFF6B6B), const Color(0xFFF1C40F),
    const Color(0xFF9B59B6), const Color(0xFFE67E22), const Color(0xFF1ABC9C),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileAndSettings();

    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _frontRotation = TweenSequence([TweenSequenceItem(tween: Tween(begin: 0.0, end: pi / 2), weight: 50), TweenSequenceItem(tween: ConstantTween(pi / 2), weight: 50)]).animate(CurvedAnimation(parent: _flipController, curve: Curves.easeInOut));
    _backRotation = TweenSequence([TweenSequenceItem(tween: ConstantTween(-pi / 2), weight: 50), TweenSequenceItem(tween: Tween(begin: -pi / 2, end: 0.0), weight: 50)]).animate(CurvedAnimation(parent: _flipController, curve: Curves.easeInOut));
  }

  void _toggleFlip() {
    if (_isFlipped) _flipController.reverse(); else _flipController.forward();
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndSettings() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('darkMode') ?? false;
        _themeColorIndex = prefs.getInt('themeIndex') ?? 0;
        _uiFontSize = prefs.getDouble('fontSize') ?? 1.0;
        _quoteFontSize = prefs.getDouble('quoteFontSize') ?? 1.0;

        // Load Notifications
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
        final hour = prefs.getInt('notification_hour') ?? 9;
        final minute = prefs.getInt('notification_minute') ?? 0;
        _notificationTime = TimeOfDay(hour: hour, minute: minute);

        _email = user.email ?? "No Email";

        // Sync Global State
        AppSettings().updateUiFontSize(_uiFontSize);
        AppSettings().updateQuoteFontSize(_quoteFontSize);
      });

      final data = await supabase.from('profiles').select('full_name, username, avatar_url, created_at, settings').eq('id', user.id).maybeSingle();

      if (mounted && data != null) {
        setState(() {
          _fullName = data['full_name'] ?? "Unknown Agent";
          _username = data['username'] ?? "anon";
          _avatarUrl = data['avatar_url'];
          if (data['created_at'] != null) _joinedDate = DateFormat('MMM-d-yyyy').format(DateTime.parse(data['created_at']));

          if (data['settings'] != null) {
            final settings = data['settings'];
            _isDarkMode = settings['darkMode'] ?? _isDarkMode;
            _themeColorIndex = settings['themeIndex'] ?? _themeColorIndex;
            _uiFontSize = (settings['fontSize'] as num?)?.toDouble() ?? _uiFontSize;
            _quoteFontSize = (settings['quoteFontSize'] as num?)?.toDouble() ?? _quoteFontSize;
            _saveLocalSettings();

            AppSettings().updateUiFontSize(_uiFontSize);
            AppSettings().updateQuoteFontSize(_quoteFontSize);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting({bool? darkMode, int? themeIndex, double? uiFontSize, double? quoteFontSize}) async {
    setState(() {
      if (darkMode != null) _isDarkMode = darkMode;
      if (themeIndex != null) _themeColorIndex = themeIndex;
      if (uiFontSize != null) {
        _uiFontSize = uiFontSize;
        AppSettings().updateUiFontSize(uiFontSize);
      }
      if (quoteFontSize != null) {
        _quoteFontSize = quoteFontSize;
        AppSettings().updateQuoteFontSize(quoteFontSize);
      }
    });
    await _saveLocalSettings();
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase.from('profiles').update({
          'settings': {
            'darkMode': _isDarkMode,
            'themeIndex': _themeColorIndex,
            'fontSize': _uiFontSize,
            'quoteFontSize': _quoteFontSize
          }
        }).eq('id', user.id);
      } catch (e) { /* silent fail */ }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationsEnabled = value);
    await prefs.setBool('notifications_enabled', value);

    if (value) {
      await NotificationManager().requestPermissions();
      await NotificationManager().scheduleDailyNotification(_notificationTime);
    } else {
      await NotificationManager().cancelNotifications();
    }
  }

  Future<void> _pickNotificationTime() async {
    if (!_notificationsEnabled) return;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        final Color accentColor = _themeColors[_themeColorIndex];
        return Theme(
          data: _isDarkMode
              ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: accentColor, onPrimary: Colors.white, surface: const Color(0xFF2C2C2C), onSurface: Colors.white),
          )
              : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: accentColor, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _notificationTime) {
      setState(() => _notificationTime = picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_hour', picked.hour);
      await prefs.setInt('notification_minute', picked.minute);
      await NotificationManager().scheduleDailyNotification(picked);
    }
  }

  // === NEW: Test Notification Action ===
  Future<void> _testNotification() async {
    await NotificationManager().showTestNotification();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification sent! (Check status bar)")));
  }

  Future<void> _saveLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
    await prefs.setInt('themeIndex', _themeColorIndex);
    await prefs.setDouble('fontSize', _uiFontSize);
    await prefs.setDouble('quoteFontSize', _quoteFontSize);
  }

  Future<void> _updateProfileField(String field, String value) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').update({field: value}).eq('id', user.id);
      setState(() {
        if (field == 'full_name') _fullName = value;
        if (field == 'username') _username = value;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showEditDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 3), boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("EDIT ${title.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 20),
              FunkyTextField(label: title, controller: controller, icon: Icons.edit),
              const SizedBox(height: 20),
              FunkyButton(text: "SAVE", color: const Color(0xFF4ECDC4), onPressed: () { if (controller.text.isNotEmpty) { _updateProfileField(field, controller.text.trim()); Navigator.pop(ctx); } })
            ]),
          ),
        )
    );
  }

  Future<void> _resetPassword() async {
    try {
      await supabase.auth.resetPasswordForEmail(_email, redirectTo: 'com.adikr.quotevault://reset-callback');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password reset email sent!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LandingPage()), (route) => false);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
      if (pickedFile == null) return;
      setState(() => _isUploading = true);
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final file = File(pickedFile.path);
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await supabase.storage.from('avatars').upload(fileName, file, fileOptions: const FileOptions(upsert: true));
      final newUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      await supabase.from('profiles').update({'avatar_url': newUrl}).eq('id', user.id);
      if (mounted) { setState(() { _avatarUrl = newUrl; _isUploading = false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Photo Updated!"))); }
    } catch (e) { if (mounted) { setState(() => _isUploading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red)); } }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) { await supabase.from('profiles').update({'avatar_url': null}).eq('id', user.id); setState(() { _avatarUrl = null; _isUploading = false; }); }
    } catch (e) { setState(() => _isUploading = false); }
  }

  void _showExpandedAvatar(BuildContext context) {
    showDialog(context: context, barrierColor: Colors.black.withOpacity(0.9), builder: (ctx) => Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.symmetric(horizontal: 10), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 360, height: 250, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        Hero(tag: 'avatar-hero-expanded', child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))], color: Colors.grey[200], image: _avatarUrl != null ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null), child: _avatarUrl == null ? const Icon(Icons.person, size: 100, color: Colors.grey) : null)),
        Positioned(left: 0, child: GestureDetector(onTap: () { Navigator.pop(ctx); _pickAndUploadImage(); }, child: Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]), child: Icon(_avatarUrl == null ? Icons.add_a_photo : Icons.edit, color: Colors.white, size: 28)), const SizedBox(height: 8), Text(_avatarUrl == null ? "ADD" : "EDIT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]))),
        if (_avatarUrl != null) Positioned(right: 0, child: GestureDetector(onTap: () { Navigator.pop(ctx); _removePhoto(); }, child: Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]), child: const Icon(Icons.delete_forever, color: Colors.white, size: 28)), const SizedBox(height: 8), const Text("REMOVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]))),
      ])),
      const SizedBox(height: 20), GestureDetector(onTap: () => Navigator.pop(ctx), child: const Text("TAP OUTSIDE TO CLOSE", style: TextStyle(color: Colors.white54, letterSpacing: 2)))
    ])));
  }

  void _showEditOverlay() {
    showDialog(context: context, barrierColor: Colors.black.withOpacity(0.8), builder: (ctx) {
      final Color accentColor = _themeColors[_themeColorIndex];
      final Color cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
      final Color textColor = _isDarkMode ? Colors.white : Colors.black;
      return Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(20), child: _buildEditableIDCard(cardColor, textColor, accentColor, ctx));
    });
  }

  Widget _buildFrontCard(Color cardColor, Color textColor, Color accentColor) {
    return Container(height: 250, width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: textColor, width: 3), boxShadow: [BoxShadow(color: textColor.withOpacity(0.3), offset: const Offset(6, 6), blurRadius: 0)]), child: Stack(children: [
      Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [GestureDetector(onTap: _toggleFlip, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.qr_code_scanner, size: 30, color: textColor))), const SizedBox(width: 10), GestureDetector(onTap: _showEditOverlay, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.edit, size: 20, color: textColor)))]),
          const Text("QUOTEVAULT ID", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 2))
        ]),
        const SizedBox(height: 15),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(tag: 'avatar-hero', child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: textColor, width: 3), color: Colors.grey[200], image: _avatarUrl != null ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null), child: _isUploading ? CircularProgressIndicator(color: accentColor) : (_avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null))),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(_fullName.toUpperCase(), style: TextStyle(fontSize: 18 * _uiFontSize, fontWeight: FontWeight.w900, color: textColor), overflow: TextOverflow.ellipsis, maxLines: 2)),
            const SizedBox(height: 4), Flexible(child: Text("@${_username.toLowerCase()}", style: TextStyle(fontSize: 14 * _uiFontSize, color: Colors.grey, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 4), Flexible(child: Text(_email, style: TextStyle(fontSize: 10 * _uiFontSize, color: Colors.grey[600], fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 8), Transform.rotate(angle: -0.05, child: Text(_username, style: GoogleFonts.greatVibes(fontSize: 24 * _uiFontSize, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.8)), overflow: TextOverflow.ellipsis))
          ]))
        ])),
        Align(alignment: Alignment.bottomLeft, child: Text("ISSUED: $_joinedDate", style: TextStyle(fontSize: 10 * _uiFontSize, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor))),
      ]),
      Positioned(bottom: 0, right: 0, child: Opacity(opacity: 0.4, child: Transform.rotate(angle: -0.2, child: Image.asset('assets/approved.png', width: 80)))),
    ]));
  }

  Widget _buildEditableIDCard(Color cardColor, Color textColor, Color accentColor, BuildContext dialogContext) {
    return Container(height: 300, width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: textColor, width: 3), boxShadow: [BoxShadow(color: textColor.withOpacity(0.3), offset: const Offset(6, 6), blurRadius: 0)]), child: Stack(children: [
      Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(Icons.qr_code_2, size: 40, color: textColor.withOpacity(0.5)), Text("EDITING MODE", style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, letterSpacing: 2))]),
        const SizedBox(height: 20),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: () { Navigator.pop(dialogContext); _showExpandedAvatar(context); }, child: Stack(children: [
            Hero(tag: 'avatar-hero-edit', child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: textColor, width: 3), color: Colors.grey[200], image: _avatarUrl != null ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null), child: _avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null)),
            Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle), child: const Icon(Icons.edit, size: 12, color: Colors.white)))
          ])),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(onTap: () { Navigator.pop(dialogContext); _showEditDialog("Full Name", "full_name", _fullName); }, child: Row(children: [Flexible(child: Text(_fullName.toUpperCase(), style: TextStyle(fontSize: 18 * _uiFontSize, fontWeight: FontWeight.w900, color: textColor, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted), overflow: TextOverflow.ellipsis, maxLines: 2)), const SizedBox(width: 5), Icon(Icons.edit, size: 16, color: accentColor)])),
            const SizedBox(height: 10), GestureDetector(onTap: () { Navigator.pop(dialogContext); _showEditDialog("Username", "username", _username); }, child: Row(children: [Flexible(child: Text("@${_username.toLowerCase()}", style: TextStyle(fontSize: 14 * _uiFontSize, color: Colors.grey, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted), overflow: TextOverflow.ellipsis)), const SizedBox(width: 5), Icon(Icons.edit, size: 14, color: accentColor)])),
            const SizedBox(height: 10), Text(_email, style: TextStyle(fontSize: 10 * _uiFontSize, color: Colors.grey[600], fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis),
          ]))
        ])),
        Align(alignment: Alignment.bottomLeft, child: Text("ISSUED: $_joinedDate", style: TextStyle(fontSize: 10 * _uiFontSize, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor.withOpacity(0.6)))),
      ]),
      Positioned(top: 0, right: 0, child: IconButton(onPressed: () => Navigator.pop(dialogContext), icon: Icon(Icons.close, color: textColor)))
    ]));
  }

  Widget _buildBackCard(Color cardColor, Color textColor, Color accentColor) {
    final String deepLink = "quotevault.com/id/@${_username.toLowerCase()}";
    return Container(height: 250, width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF222222) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20), border: Border.all(color: accentColor, width: 3), boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), offset: const Offset(-6, 6), blurRadius: 0)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      QrImageView(data: deepLink, version: QrVersions.auto, size: 130.0, foregroundColor: textColor),
      const SizedBox(height: 15), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(5)), child: Text(deepLink, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white), textAlign: TextAlign.center)),
      const SizedBox(height: 5), const Text("SCAN TO VERIFY", style: TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.grey)),
    ]));
  }

  Widget _buildRealisticSwitch() {
    return GestureDetector(
      onTap: () => _updateSetting(darkMode: !_isDarkMode),
      child: AnimatedContainer(duration: const Duration(milliseconds: 300), width: 60, height: 30, padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF2C3E50) : const Color(0xFF87CEEB), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]), child: Stack(alignment: Alignment.center, children: [
        AnimatedPositioned(duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, left: _isDarkMode ? 30 : 0, child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: _isDarkMode ? const Color(0xFFF1C40F) : const Color(0xFFF39C12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]), child: Icon(_isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded, size: 16, color: Colors.white))),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _themeColors[_themeColorIndex];
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final Color cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text("AGENT PROFILE", style: TextStyle(color: textColor, fontWeight: FontWeight.w900, letterSpacing: 2)), centerTitle: true, actions: [IconButton(icon: Icon(Icons.logout, color: textColor), onPressed: _logout)]),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _toggleFlip,
              child: Stack(children: [
                AnimatedBuilder(animation: _frontRotation, builder: (context, child) { final angle = _frontRotation.value; return Transform(transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle), alignment: Alignment.center, child: angle >= pi / 2 ? const SizedBox() : _buildFrontCard(cardColor, textColor, accentColor)); }),
                AnimatedBuilder(animation: _backRotation, builder: (context, child) { final angle = _backRotation.value; return Transform(transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle), alignment: Alignment.center, child: angle <= -pi / 2 ? const SizedBox() : _buildBackCard(cardColor, textColor, accentColor)); }),
              ]),
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: textColor.withOpacity(0.1), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("PREFERENCES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.grey, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Interface Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * _uiFontSize, color: textColor)), _buildRealisticSwitch()]),
                const SizedBox(height: 20),
                Text("Signature Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * _uiFontSize, color: textColor)),
                const SizedBox(height: 10),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(_themeColors.length, (index) { final isSelected = _themeColorIndex == index; return GestureDetector(onTap: () => _updateSetting(themeIndex: index), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 15), width: isSelected ? 45 : 35, height: isSelected ? 45 : 35, decoration: BoxDecoration(color: _themeColors[index], shape: BoxShape.circle, border: Border.all(color: isSelected ? textColor : Colors.transparent, width: 3)), child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null)); }))),
                const SizedBox(height: 20),

                // UI Font Size Slider
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Interface Size", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * _uiFontSize, color: textColor)), Text("${(_uiFontSize * 100).round()}%", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: accentColor))]),
                SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: accentColor, thumbColor: accentColor, inactiveTrackColor: accentColor.withOpacity(0.2), trackHeight: 4), child: Slider(value: _uiFontSize, min: 0.8, max: 1.4, divisions: 6, onChanged: (val) => _updateSetting(uiFontSize: val))),

                const SizedBox(height: 10),

                // Quote Text Size Slider
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Quote Text Size", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * _uiFontSize, color: textColor)), Text("${(_quoteFontSize * 100).round()}%", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: accentColor))]),
                SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: accentColor, thumbColor: accentColor, inactiveTrackColor: accentColor.withOpacity(0.2), trackHeight: 4), child: Slider(value: _quoteFontSize, min: 0.8, max: 2.0, divisions: 12, onChanged: (val) => _updateSetting(quoteFontSize: val))),

                const SizedBox(height: 20),

                // === NOTIFICATION SETTINGS UI ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Daily Quote", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * _uiFontSize, color: textColor)),
                    Switch(
                        value: _notificationsEnabled,
                        activeColor: accentColor,
                        onChanged: _toggleNotifications
                    ),
                  ],
                ),
                if (_notificationsEnabled) ...[
                  const SizedBox(height: 10),
                  // NEW: Time and Test Button Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickNotificationTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accentColor.withOpacity(0.3))
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 18, color: accentColor),
                                const SizedBox(width: 8),
                                Text("Time: ${_notificationTime.format(context)}", style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // TEST BUTTON
                      GestureDetector(
                        onTap: _testNotification,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.withOpacity(0.5))
                          ),
                          child: Text("TEST", style: TextStyle(fontWeight: FontWeight.bold, color: textColor.withOpacity(0.8))),
                        ),
                      ),
                    ],
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: Column(children: [FunkyButton(text: "RESET PASSWORD", color: Colors.orange, textColor: Colors.white, onPressed: _resetPassword), const SizedBox(height: 15), FunkyButton(text: "LOGOUT", color: Colors.red, textColor: Colors.white, onPressed: _logout)])),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}