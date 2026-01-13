import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../profile/profile_page.dart';
import 'quotes_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Theme and Profile State
  bool _isDarkMode = false;
  int _themeColorIndex = 0;
  String? _avatarUrl;
  bool _isLoadingProfile = true;

  final PageController _pageController = PageController();
  // Start with scrolling enabled
  ScrollPhysics _scrollPhysics = const BouncingScrollPhysics();

  // Theme Colors
  final List<Color> _themeColors = const [
    Color(0xFF4ECDC4), Color(0xFFFF6B6B), Color(0xFFF1C40F),
    Color(0xFF9B59B6), Color(0xFFE67E22), Color(0xFF1ABC9C),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndProfile();
  }

  Future<void> _loadSettingsAndProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _themeColorIndex = prefs.getInt('themeIndex') ?? 0;
    });

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
          setState(() {
            _avatarUrl = data?['avatar_url'];
            _isLoadingProfile = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _themeColors[_themeColorIndex];
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    final Color cardColor = _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "QUOTE VAULT",
          style: GoogleFonts.spaceMono(
            color: textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                _loadSettingsAndProfile();
              },
              child: _isLoadingProfile
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: accentColor, strokeWidth: 2))
                  : Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? Icon(Icons.person, color: Colors.grey[600], size: 28)
                      : null,
                ),
              ),
            ),
          )
        ],
      ),
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: _scrollPhysics, // Dynamic physics
        onPageChanged: (index) {
          // === LOCK SCROLLING ONCE WE REACH QUOTES PAGE ===
          if (index == 1) {
            setState(() {
              _scrollPhysics = const NeverScrollableScrollPhysics();
            });
          }
        },
        children: [
          // Page 1: Landing
          HomeLandingView(
            textColor: textColor,
            accentColor: accentColor,
            onScrollDown: () {
              _pageController.animateToPage(1, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
            },
          ),
          // Page 2: Quotes
          QuotesPage(
            accentColor: accentColor,
            cardColor: cardColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

class HomeLandingView extends StatelessWidget {
  final Color textColor;
  final Color accentColor;
  final VoidCallback onScrollDown;

  const HomeLandingView({
    super.key,
    required this.textColor,
    required this.accentColor,
    required this.onScrollDown,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.1),
            ),
          ),
        ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(Icons.format_quote_rounded, size: 180, color: accentColor),
              const SizedBox(height: 40),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.spaceMono(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1.1,
                  ),
                  children: [
                    const TextSpan(text: "Dive Into\n"),
                    TextSpan(
                      text: "QuoteVerse",
                      style: TextStyle(
                        color: accentColor,
                        shadows: [
                          Shadow(color: accentColor.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 5))
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              GestureDetector(
                onTap: onScrollDown,
                child: Column(
                  children: [
                    Text(
                      "Scroll to discover",
                      style: GoogleFonts.spaceMono(
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Icon(Icons.keyboard_double_arrow_down_rounded, color: accentColor, size: 40),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    );
  }
}