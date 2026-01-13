import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../main.dart';
import '../profile/profile_page.dart';
import 'quotes_page.dart';
import 'quote_share_sheet.dart';

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

  // Daily Quote State
  Map<String, dynamic>? _dailyQuote;
  Set<String> _dailyQuoteCollections = {};
  bool _isLoadingDailyStatus = false;

  final PageController _pageController = PageController();
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
    _fetchDailyQuote();
  }

  Future<void> _fetchDailyQuote() async {
    try {
      final countResponse = await supabase.from('quotes').count();
      if (countResponse > 0) {
        final now = DateTime.now();
        final diff = now.difference(DateTime(now.year, 1, 1, 0, 0));
        final dayOfYear = diff.inDays;
        final dailyIndex = dayOfYear % countResponse;

        final data = await supabase
            .from('quotes')
            .select()
            .range(dailyIndex, dailyIndex)
            .maybeSingle();

        if (mounted && data != null) {
          setState(() {
            _dailyQuote = data;
          });
          _fetchDailyQuoteStatus(data['id']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching daily quote: $e");
    }
  }

  Future<void> _fetchDailyQuoteStatus(String quoteId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoadingDailyStatus = true);
    try {
      final savedData = await supabase
          .from('saved_quotes')
          .select('collection')
          .eq('user_id', user.id)
          .eq('quote_id', quoteId);

      if (mounted) {
        setState(() {
          _dailyQuoteCollections = savedData.map((e) => e['collection'] as String).toSet();
          _isLoadingDailyStatus = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDailyStatus = false);
    }
  }

  Future<void> _toggleDailyCollection(String collectionName) async {
    final user = supabase.auth.currentUser;
    if (user == null || _dailyQuote == null) return;
    HapticFeedback.mediumImpact();

    final quoteId = _dailyQuote!['id'];
    final exists = _dailyQuoteCollections.contains(collectionName);

    setState(() {
      if (exists) {
        _dailyQuoteCollections.remove(collectionName);
      } else {
        _dailyQuoteCollections.add(collectionName);
      }
    });

    try {
      if (exists) {
        await supabase.from('saved_quotes')
            .delete()
            .eq('user_id', user.id)
            .eq('quote_id', quoteId)
            .eq('collection', collectionName);
      } else {
        await supabase.from('saved_quotes').insert({
          'user_id': user.id,
          'quote_id': quoteId,
          'content': _dailyQuote!['content'],
          'author': _dailyQuote!['author'],
          'collection': collectionName,
        });
      }
    } catch (e) {
      debugPrint("Error toggling daily collection: $e");
      if (mounted) {
        setState(() {
          if (exists) _dailyQuoteCollections.add(collectionName);
          else _dailyQuoteCollections.remove(collectionName);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating status")));
      }
    }
  }

  void _openShareSheet() {
    if (_dailyQuote == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuoteShareSheet(
        quote: _dailyQuote!['content'],
        author: _dailyQuote!['author'],
        accentColor: _themeColors[_themeColorIndex],
      ),
    );
  }

  void _openDailyCollectionSheet() {
    if (_dailyQuote == null) return;
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _HomeCollectionSheet(
        accentColor: _themeColors[_themeColorIndex],
        cardColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
        textColor: _isDarkMode ? Colors.white : Colors.black,
        activeCollections: _dailyQuoteCollections,
        onToggle: _toggleDailyCollection,
      ),
    );
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
        // === NEW: CLICKABLE TITLE ===
        title: GestureDetector(
          onTap: () {
            // Reset to Landing Page
            _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic
            );
          },
          child: Text(
            "QUOTE VAULT",
            style: GoogleFonts.spaceMono(
              color: textColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 24,
            ),
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
                if (_dailyQuote != null) _fetchDailyQuoteStatus(_dailyQuote!['id']);
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
        physics: _scrollPhysics,
        onPageChanged: (index) {
          if (index == 1) {
            setState(() {
              _scrollPhysics = const NeverScrollableScrollPhysics();
            });
          } else {
            // Re-enable scrolling if we go back to landing
            setState(() {
              _scrollPhysics = const BouncingScrollPhysics();
            });
          }
        },
        children: [
          HomeLandingView(
            textColor: textColor,
            accentColor: accentColor,
            cardColor: cardColor,
            dailyQuote: _dailyQuote,
            isFavorite: _dailyQuoteCollections.contains('Favorites'),
            isBookmarked: _dailyQuoteCollections.any((c) => c != 'Favorites'),
            onFavoriteTap: () => _toggleDailyCollection('Favorites'),
            onBookmarkTap: _openDailyCollectionSheet,
            onShareTap: _openShareSheet,
            onScrollDown: () {
              _pageController.animateToPage(1, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
            },
          ),
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
  final Color cardColor;
  final VoidCallback onScrollDown;
  final Map<String, dynamic>? dailyQuote;
  final bool isFavorite;
  final bool isBookmarked;
  final VoidCallback onFavoriteTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onShareTap;

  const HomeLandingView({
    super.key,
    required this.textColor,
    required this.accentColor,
    required this.cardColor,
    required this.onScrollDown,
    this.dailyQuote,
    required this.isFavorite,
    required this.isBookmarked,
    required this.onFavoriteTap,
    required this.onBookmarkTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100, left: -100,
          child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withOpacity(0.1))),
        ),

        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // === 1. PUSH DOWN (Center Group) ===
              const Spacer(flex: 2),

              // === 2. TITLE ===
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.spaceMono(fontSize: 40, fontWeight: FontWeight.w900, color: textColor, height: 1.1),
                  children: [
                    const TextSpan(text: "Dive Into\n"),
                    TextSpan(text: "QuoteVerse", style: TextStyle(color: accentColor, shadows: [Shadow(color: accentColor.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 5))])),
                  ],
                ),
              ),

              // === 3. CLOSER SPACING ===
              const SizedBox(height: 40),

              // === 4. FUNKY DAILY QUOTE BOX ===
              if (dailyQuote != null)
                DailyQuoteBox(
                  quoteContent: dailyQuote!['content'],
                  quoteAuthor: dailyQuote!['author'],
                  accentColor: accentColor,
                  cardColor: cardColor,
                  textColor: textColor,
                  isFavorite: isFavorite,
                  isBookmarked: isBookmarked,
                  onFavoriteTap: onFavoriteTap,
                  onBookmarkTap: onBookmarkTap,
                  onShareTap: onShareTap,
                )
              else
                Container(
                  height: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
                  ),
                  child: Center(child: CircularProgressIndicator(color: accentColor)),
                ),

              // === 5. BOTTOM SPACER ===
              const Spacer(flex: 3),

              // Scroll Indicator
              GestureDetector(
                onTap: onScrollDown,
                child: Column(
                  children: [
                    Text("Scroll to discover", style: GoogleFonts.spaceMono(color: textColor.withOpacity(0.6), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Icon(Icons.keyboard_double_arrow_down_rounded, color: accentColor, size: 40),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

class DailyQuoteBox extends StatefulWidget {
  final String quoteContent;
  final String quoteAuthor;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final bool isFavorite;
  final bool isBookmarked;
  final VoidCallback onFavoriteTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onShareTap;

  const DailyQuoteBox({
    super.key,
    required this.quoteContent,
    required this.quoteAuthor,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.isFavorite,
    required this.isBookmarked,
    required this.onFavoriteTap,
    required this.onBookmarkTap,
    required this.onShareTap,
  });

  @override
  State<DailyQuoteBox> createState() => _DailyQuoteBoxState();
}

class _DailyQuoteBoxState extends State<DailyQuoteBox> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _heartScale = Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(parent: _heartController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.accentColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "QUOTE OF THE DAY",
              style: GoogleFonts.spaceMono(
                color: widget.textColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '"${widget.quoteContent}"',
            style: GoogleFonts.notoSans(
              color: widget.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "- ${widget.quoteAuthor}",
            style: GoogleFonts.spaceMono(
              color: widget.textColor.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: widget.onShareTap,
                icon: Icon(Icons.share_rounded, color: widget.accentColor),
                style: IconButton.styleFrom(backgroundColor: widget.accentColor.withOpacity(0.1)),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: widget.onBookmarkTap,
                icon: Icon(
                    widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                    color: widget.accentColor
                ),
                style: IconButton.styleFrom(
                    backgroundColor: widget.accentColor.withOpacity(0.1)
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  widget.onFavoriteTap();
                  _heartController.forward(from: 0.0);
                },
                child: ScaleTransition(
                  scale: _heartScale,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.isFavorite ? Colors.redAccent.withOpacity(0.1) : widget.accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                      color: widget.isFavorite ? Colors.redAccent : widget.accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeCollectionSheet extends StatefulWidget {
  final Color accentColor, cardColor, textColor;
  final Set<String> activeCollections;
  final Function(String) onToggle;
  const _HomeCollectionSheet({required this.accentColor, required this.cardColor, required this.textColor, required this.activeCollections, required this.onToggle});
  @override State<_HomeCollectionSheet> createState() => _HomeCollectionSheetState();
}
class _HomeCollectionSheetState extends State<_HomeCollectionSheet> {
  List<String> collections = []; bool _loading = true; bool _creating = false; final _ctrl = TextEditingController();
  @override void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async {
    final res = await supabase.from('collections').select('name').order('name', ascending: true);
    if(mounted) setState(() { collections = List<String>.from(res.map((e)=>e['name'])); _loading = false; });
  }
  Future<void> _add() async {
    final t = _ctrl.text.trim(); if(t.isEmpty) return;
    setState(() { collections.add(t); _creating = false; });
    await supabase.from('collections').insert({'name': t, 'user_id': supabase.auth.currentUser?.id});
    widget.onToggle(t);
  }
  Color _getContrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: widget.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("MANAGE COLLECTIONS", style: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, fontSize: 16, color: widget.textColor)), IconButton(icon: Icon(Icons.close, color: widget.textColor), onPressed: ()=>Navigator.pop(context))]), const SizedBox(height: 20), if(_loading) Center(child: CircularProgressIndicator(color: widget.accentColor)) else if(_creating) Row(children: [Expanded(child: TextField(controller: _ctrl, autofocus: true, style: TextStyle(color: widget.textColor), decoration: InputDecoration(hintText: "Name", hintStyle: TextStyle(color: widget.textColor.withOpacity(0.5)), border: UnderlineInputBorder(borderSide: BorderSide(color: widget.accentColor)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.accentColor))))), IconButton(onPressed: _add, icon: Icon(Icons.check, color: widget.accentColor))]) else Wrap(spacing: 12, runSpacing: 12, children: [...collections.map((c) { final isSelected = widget.activeCollections.contains(c); return GestureDetector(onTap: () => widget.onToggle(c), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? widget.accentColor : Colors.transparent, borderRadius: BorderRadius.circular(30), border: Border.all(color: isSelected ? widget.accentColor : widget.textColor.withOpacity(0.6), width: 1.5)), child: Text(c, style: GoogleFonts.spaceMono(color: isSelected ? _getContrastColor(widget.accentColor) : widget.textColor, fontWeight: FontWeight.bold, fontSize: 14)))); }), GestureDetector(onTap: ()=>setState(()=>_creating=true), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(30), border: Border.all(color: widget.textColor.withOpacity(0.6), width: 1.5)), child: Icon(Icons.add, size: 18, color: widget.textColor)))]), const SizedBox(height: 40)]));
  }
}