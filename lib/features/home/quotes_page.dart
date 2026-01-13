import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import 'quote_card.dart';

class QuotesPage extends StatefulWidget {
  final Color accentColor;
  final Color cardColor;
  final Color textColor;

  const QuotesPage({
    super.key,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
  });

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> with TickerProviderStateMixin {
  // Data
  List<Map<String, dynamic>> _quotes = [];
  final Map<String, Set<String>> _savedCollections = {};

  // UI State
  bool _isLoading = true;
  bool _showIntro = true;
  final CardSwiperController _swiperController = CardSwiperController();
  final TextEditingController _searchController = TextEditingController();

  // Filters
  String? _activeCollectionFilter;
  String? _searchQuery;
  final Set<String> _selectedCategories = {};

  // Animations
  late AnimationController _introController;
  final List<Animation<Offset>> _cardAnimations = [];
  late AnimationController _refreshIconController;

  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  final double _refreshThreshold = 100.0;

  final int _stackCount = 5;

  final List<String> _allCategories = ['Motivation', 'Love', 'Wisdom', 'Humor', 'Success'];

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _showIntro = false);
    });

    _refreshIconController = AnimationController(
      vsync: this, duration: const Duration(seconds: 1),
    )..repeat();

    _fetchQuotes();
  }

  Future<void> _fetchQuotes() async {
    setState(() { _isLoading = true; _showIntro = false; });
    try {
      final user = supabase.auth.currentUser;
      dynamic response;

      // 1. FILTER BY COLLECTION
      if (_activeCollectionFilter != null && user != null) {
        final savedData = await supabase
            .from('saved_quotes')
            .select('quote_id')
            .eq('user_id', user.id)
            .eq('collection', _activeCollectionFilter as String);

        final ids = List<String>.from(savedData.map((e) => e['quote_id']));

        if (ids.isEmpty) {
          response = [];
        } else {
          var query = supabase.from('quotes').select().filter('id', 'in', ids);

          if (_selectedCategories.isNotEmpty) {
            query = query.filter('category', 'in', _selectedCategories.toList());
          }

          if (_searchQuery != null && _searchQuery!.isNotEmpty) {
            query = query.or('content.ilike.%$_searchQuery%,author.ilike.%$_searchQuery%');
          }
          response = await query.limit(_stackCount);
        }
      }
      // 2. GLOBAL SEARCH / RANDOM
      else {
        var query = supabase.from('quotes').select();

        if (_selectedCategories.isNotEmpty) {
          query = query.filter('category', 'in', _selectedCategories.toList());
        }

        if (_searchQuery != null && _searchQuery!.isNotEmpty) {
          query = query.or('content.ilike.%$_searchQuery%,author.ilike.%$_searchQuery%');
          response = await query.limit(_stackCount);
        } else {
          if (_selectedCategories.isNotEmpty) {
            response = await query.limit(_stackCount);
          } else {
            final countResponse = await supabase.from('quotes').count();
            int offset = 0;
            if (countResponse > _stackCount) {
              offset = Random().nextInt(countResponse - _stackCount);
            }
            response = await query.range(offset, offset + (_stackCount - 1));
          }
        }
      }

      final fetchedQuotes = List<Map<String, dynamic>>.from(response);

      if (user != null && fetchedQuotes.isNotEmpty) {
        final ids = fetchedQuotes.map((q) => q['id']).toList();
        final savedData = await supabase
            .from('saved_quotes')
            .select('quote_id, collection')
            .eq('user_id', user.id)
            .filter('quote_id', 'in', ids);

        _savedCollections.clear();
        for (var item in savedData) {
          final qId = item['quote_id'] as String;
          final col = item['collection'] as String;
          if (!_savedCollections.containsKey(qId)) _savedCollections[qId] = {};
          _savedCollections[qId]!.add(col);
        }
      }

      if (mounted) {
        setState(() {
          _quotes = fetchedQuotes;
          if (_activeCollectionFilter == null && _searchQuery == null && _selectedCategories.isEmpty) {
            _quotes.shuffle();
          }
          _isLoading = false;
          _showIntro = true;
        });
        _prepareCardAnimations(_quotes.length);
        HapticFeedback.mediumImpact();
        _introController.reset();
        _introController.forward();
      }
    } catch (e) {
      debugPrint("Error fetching quotes: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prepareCardAnimations(int count) {
    _cardAnimations.clear();
    final intervalStep = 0.8 / (count == 0 ? 1 : count);
    for (int i = 0; i < count; i++) {
      final reverseI = count - 1 - i;
      final start = reverseI * intervalStep;
      final end = start + 0.4;
      final double startX = (Random().nextDouble() * 2 - 1) * 1.5;
      final double startY = 1.5;
      _cardAnimations.add(
        Tween<Offset>(begin: Offset(startX, startY), end: Offset.zero).animate(
            CurvedAnimation(parent: _introController, curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutBack))
        ),
      );
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    await _fetchQuotes();
    if (mounted) setState(() { _isRefreshing = false; _dragOffset = 0.0; });
  }

  Future<void> _toggleCollection(Map<String, dynamic> quote, String collectionName) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    HapticFeedback.mediumImpact();
    final quoteId = quote['id'];
    final currentSet = _savedCollections[quoteId] ?? {};
    final exists = currentSet.contains(collectionName);

    try {
      if (exists) {
        await supabase.from('saved_quotes').delete().eq('user_id', user.id).eq('quote_id', quoteId).eq('collection', collectionName);
        setState(() {
          _savedCollections[quoteId]?.remove(collectionName);
          if (_savedCollections[quoteId]?.isEmpty ?? false) _savedCollections.remove(quoteId);
        });
      } else {
        await supabase.from('saved_quotes').insert({
          'user_id': user.id, 'quote_id': quoteId, 'content': quote['content'], 'author': quote['author'], 'collection': collectionName,
        });
        setState(() {
          if (!_savedCollections.containsKey(quoteId)) _savedCollections[quoteId] = {};
          _savedCollections[quoteId]!.add(collectionName);
        });
      }
    } catch (e) {
      debugPrint("Error toggling: $e");
    }
  }

  void _openCollectionSheet(Map<String, dynamic> quote) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => _CollectionSheet(
        accentColor: widget.accentColor, cardColor: widget.cardColor, textColor: widget.textColor,
        activeCollections: _savedCollections[quote['id']] ?? {},
        onToggle: (collection) => _toggleCollection(quote, collection),
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().isEmpty ? null : value.trim());
    _fetchQuotes();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
    _fetchQuotes();
  }

  void _toggleFavoritesFilter() {
    setState(() => _activeCollectionFilter = (_activeCollectionFilter == 'Favorites') ? null : 'Favorites');
    _fetchQuotes();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent,
        builder: (context) => _FilterCollectionPicker(
          accentColor: widget.accentColor,
          cardColor: widget.cardColor,
          textColor: widget.textColor,
          currentCollection: _activeCollectionFilter, // <--- Pass Current Selection
          onSelect: (collection) {
            Navigator.pop(context);
            setState(() => _activeCollectionFilter = collection);
            _fetchQuotes();
          },
          onClear: () {
            Navigator.pop(context);
            setState(() => _activeCollectionFilter = null);
            _fetchQuotes();
          },
        )
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'motivation': return const Color(0xFFFFD700);
      case 'love': return const Color(0xFFFF6B6B);
      case 'wisdom': return const Color(0xFF5D9CEC);
      case 'humor': return const Color(0xFFFF9F43);
      case 'success': return const Color(0xFF2ECC71);
      default: return widget.accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double searchBarTop = statusBarHeight + 4;
    final double categoryRowTop = searchBarTop + 50 + 10;
    final double cardsTop = categoryRowTop + 40 + 30;

    int displayCount = 3;
    if (_quotes.length < 3) displayCount = _quotes.length;
    if (displayCount < 1 && _quotes.isNotEmpty) displayCount = 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (_isLoading || _isRefreshing || _showIntro) return;
          if (details.delta.dy > 0 || _dragOffset > 0) {
            setState(() {
              _dragOffset += details.delta.dy * 0.5;
              if (_dragOffset > 150) _dragOffset = 150;
              if (_dragOffset < 0) _dragOffset = 0;
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset >= _refreshThreshold) _handleRefresh();
          else setState(() => _dragOffset = 0.0);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: cardsTop + 40,
              child: Opacity(
                opacity: (_dragOffset / _refreshThreshold).clamp(0.0, 1.0),
                child: RotationTransition(
                  turns: _isRefreshing ? _refreshIconController : AlwaysStoppedAnimation(_dragOffset / 300),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: widget.cardColor, shape: BoxShape.circle, border: Border.all(color: widget.accentColor, width: 2)),
                    child: Icon(Icons.shuffle_rounded, color: widget.accentColor, size: 24),
                  ),
                ),
              ),
            ),

            // HEADER
            Positioned(
              top: searchBarTop, left: 20, right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: widget.cardColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: widget.textColor.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: _onSearchChanged,
                        style: TextStyle(color: widget.textColor),
                        decoration: InputDecoration(
                          hintText: "Search quotes...",
                          hintStyle: TextStyle(color: widget.textColor.withOpacity(0.5), fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: widget.textColor.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _toggleFavoritesFilter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: _activeCollectionFilter == 'Favorites' ? widget.accentColor : widget.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _activeCollectionFilter == 'Favorites' ? widget.accentColor : widget.textColor.withOpacity(0.2)
                        ),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Icon(Icons.favorite, color: _activeCollectionFilter == 'Favorites' ? Colors.white : Colors.redAccent, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _openFilterSheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: (_activeCollectionFilter != null && _activeCollectionFilter != 'Favorites') ? widget.accentColor : widget.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: (_activeCollectionFilter != null && _activeCollectionFilter != 'Favorites') ? widget.accentColor : widget.textColor.withOpacity(0.2)
                        ),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Icon(Icons.bookmark, color: (_activeCollectionFilter != null && _activeCollectionFilter != 'Favorites') ? Colors.white : widget.textColor, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // CATEGORIES
            Positioned(
              top: categoryRowTop,
              left: 0, right: 0,
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _allCategories.length,
                separatorBuilder: (_,__) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final cat = _allCategories[index];
                  final isSelected = _selectedCategories.contains(cat);
                  final color = _getCategoryColor(cat);
                  return GestureDetector(
                    onTap: () => _toggleCategory(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: 2),
                        boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)] : [],
                      ),
                      child: Center(
                        child: Text(
                          "#${cat.toUpperCase()}",
                          style: GoogleFonts.spaceMono(
                            color: isSelected ? Colors.white : widget.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // CARDS
            Transform.translate(
              offset: Offset(0, _isRefreshing ? 100 : _dragOffset),
              child: Padding(
                padding: EdgeInsets.fromLTRB(30, cardsTop, 30, 120),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isLoading)
                      Center(child: CircularProgressIndicator(color: widget.accentColor)),

                    if (!_isLoading && _quotes.isEmpty)
                      Center(child: Text("No quotes found.", style: GoogleFonts.spaceMono(color: widget.textColor))),

                    if (!_showIntro && !_isRefreshing && !_isLoading && _quotes.isNotEmpty)
                      CardSwiper(
                        controller: _swiperController,
                        cardsCount: _quotes.length,
                        numberOfCardsDisplayed: displayCount,
                        backCardOffset: const Offset(0, 30),
                        padding: EdgeInsets.zero,
                        cardBuilder: (context, index, pX, pY) {
                          final quote = _quotes[index];
                          final savedSet = _savedCollections[quote['id']] ?? {};
                          return QuoteCard(
                            quote: quote['content'], author: quote['author'], category: quote['category'],
                            accentColor: widget.accentColor, cardColor: widget.cardColor, textColor: widget.textColor,
                            percentX: pX / 100.0, percentY: pY / 100.0,
                            isFavorite: savedSet.contains('Favorites'),
                            isBookmarked: savedSet.any((c) => c != 'Favorites'),
                            onFavorite: () => _toggleCollection(quote, 'Favorites'),
                            onBookmark: () => _openCollectionSheet(quote),
                            onLongPress: () => _openCollectionSheet(quote),
                          );
                        },
                        onSwipe: (prev, curr, dir) => true,
                      ),

                    if ((_showIntro || _isRefreshing) && !_isLoading && _quotes.isNotEmpty)
                      ...List.generate(_quotes.length, (i) {
                        final index = _quotes.length - 1 - i;
                        final quote = _quotes[index];
                        if (index >= _cardAnimations.length) return const SizedBox();
                        final savedSet = _savedCollections[quote['id']] ?? {};
                        return AnimatedBuilder(
                          animation: _introController,
                          builder: (context, child) {
                            final v = _cardAnimations[index].value;
                            if (v.dy > 1.2) return const SizedBox();
                            return Transform.translate(
                              offset: Offset(v.dx * 300, v.dy * 800),
                              child: Transform.rotate(angle: (v.dy * 0.2) * (index % 2 == 0 ? 1 : -1), child: child),
                            );
                          },
                          child: QuoteCard(
                            quote: quote['content'], author: quote['author'], category: quote['category'],
                            accentColor: widget.accentColor, cardColor: widget.cardColor, textColor: widget.textColor,
                            isFavorite: savedSet.contains('Favorites'),
                            isBookmarked: savedSet.any((c) => c != 'Favorites'),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showIntro || _isRefreshing ? 0.0 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(30), border: Border.all(color: widget.textColor.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: () => _swiperController.swipe(CardSwiperDirection.left), icon: Icon(Icons.close_rounded, color: widget.textColor)),
              const SizedBox(width: 20),
              Text("Swipe to Dismiss", style: GoogleFonts.spaceMono(color: widget.textColor, fontWeight: FontWeight.w600)),
              const SizedBox(width: 20),
              IconButton(onPressed: () => _swiperController.swipe(CardSwiperDirection.right), icon: Icon(Icons.arrow_forward_rounded, color: widget.accentColor)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _swiperController.dispose(); _introController.dispose(); _refreshIconController.dispose(); _searchController.dispose(); super.dispose();
  }
}

// === UPDATED: MANAGE COLLECTIONS SHEET ===
class _CollectionSheet extends StatefulWidget {
  final Color accentColor, cardColor, textColor;
  final Set<String> activeCollections;
  final Function(String) onToggle;
  const _CollectionSheet({required this.accentColor, required this.cardColor, required this.textColor, required this.activeCollections, required this.onToggle});
  @override State<_CollectionSheet> createState() => _CollectionSheetState();
}
class _CollectionSheetState extends State<_CollectionSheet> {
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

  // Helper to determine text contrast
  Color _getContrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  @override Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: widget.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("MANAGE COLLECTIONS", style: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, fontSize: 16, color: widget.textColor)), IconButton(icon: Icon(Icons.close, color: widget.textColor), onPressed: ()=>Navigator.pop(context))]),
          const SizedBox(height: 20),
          if(_loading) Center(child: CircularProgressIndicator(color: widget.accentColor))
          else if(_creating) Row(children: [Expanded(child: TextField(controller: _ctrl, autofocus: true, style: TextStyle(color: widget.textColor), decoration: InputDecoration(hintText: "Name", hintStyle: TextStyle(color: widget.textColor.withOpacity(0.5)), border: UnderlineInputBorder(borderSide: BorderSide(color: widget.accentColor)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.accentColor))))), IconButton(onPressed: _add, icon: Icon(Icons.check, color: widget.accentColor))])
          else Wrap(spacing: 12, runSpacing: 12, children: [
              ...collections.map((c) {
                final isSelected = widget.activeCollections.contains(c);
                // Visual State:
                // Selected: Filled with Accent, No Border (or matching), Text is Contrast
                // Unselected: Transparent, Border is TextColor, Text is TextColor
                return GestureDetector(
                  onTap: () => widget.onToggle(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: isSelected ? widget.accentColor : widget.textColor.withOpacity(0.6),
                          width: 1.5
                      ),
                    ),
                    child: Text(
                      c,
                      style: GoogleFonts.spaceMono(
                        color: isSelected ? _getContrastColor(widget.accentColor) : widget.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
              // Add Button
              GestureDetector(
                onTap: ()=>setState(()=>_creating=true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: widget.textColor.withOpacity(0.6), width: 1.5),
                  ),
                  child: Icon(Icons.add, size: 18, color: widget.textColor),
                ),
              )
            ]),
          const SizedBox(height: 40)
        ])
    );
  }
}

// === UPDATED: VIEW/FILTER COLLECTIONS SHEET ===
class _FilterCollectionPicker extends StatefulWidget {
  final Color accentColor, cardColor, textColor;
  final String? currentCollection; // <--- Tracks active filter
  final Function(String) onSelect;
  final VoidCallback onClear;
  const _FilterCollectionPicker({required this.accentColor, required this.cardColor, required this.textColor, this.currentCollection, required this.onSelect, required this.onClear});
  @override State<_FilterCollectionPicker> createState() => _FilterCollectionPickerState();
}
class _FilterCollectionPickerState extends State<_FilterCollectionPicker> {
  List<String> collections = []; bool _loading = true;
  @override void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async {
    final res = await supabase.from('collections').select('name').order('name', ascending: true);
    if(mounted) setState(() { collections = List<String>.from(res.map((e)=>e['name'])); _loading = false; });
  }

  Color _getContrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  @override Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: widget.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("FILTER BY COLLECTION", style: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, fontSize: 16, color: widget.textColor)), IconButton(icon: Icon(Icons.close, color: widget.textColor), onPressed: ()=>Navigator.pop(context))]),
          const SizedBox(height: 20),
          if(_loading) Center(child: CircularProgressIndicator(color: widget.accentColor))
          else Wrap(spacing: 12, runSpacing: 12, children: [
            // "Show All" Chip
            GestureDetector(
              onTap: widget.onClear,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.currentCollection == null ? widget.accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: widget.currentCollection == null ? widget.accentColor : widget.textColor.withOpacity(0.6),
                      width: 1.5
                  ),
                ),
                child: Text(
                  "Show All",
                  style: GoogleFonts.spaceMono(
                    color: widget.currentCollection == null ? _getContrastColor(widget.accentColor) : widget.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // Collection Chips
            ...collections.map((c) {
              final isSelected = widget.currentCollection == c;
              return GestureDetector(
                onTap: () => widget.onSelect(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? widget.accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: isSelected ? widget.accentColor : widget.textColor.withOpacity(0.6),
                        width: 1.5
                    ),
                  ),
                  child: Text(
                    c,
                    style: GoogleFonts.spaceMono(
                      color: isSelected ? _getContrastColor(widget.accentColor) : widget.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            })
          ]),
          const SizedBox(height: 40)
        ])
    );
  }
}