import 'dart:math';
import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quote_share_sheet.dart';
import '../../managers/app_settings.dart';

// --- 1. POSTER MANAGER (Reactive Singleton) ---
// Now uses ValueNotifier so cards update automatically when data arrives
class PosterManager {
  static final PosterManager _instance = PosterManager._internal();
  factory PosterManager() => _instance;
  PosterManager._internal();

  // Notifies listeners (the cards) when the list updates
  final ValueNotifier<List<String>> postersNotifier = ValueNotifier([]);
  bool _isFetching = false;

  void fetchPosters() async {
    // If we already have data or are currently loading, do nothing
    if (postersNotifier.value.isNotEmpty || _isFetching) return;

    _isFetching = true;
    try {
      final response = await Supabase.instance.client
          .from('posters')
          .select('image_url');

      final data = response as List<dynamic>;
      final List<String> urls = data.map((row) => row['image_url'] as String).toList();

      // Update the notifier! This triggers the UI update in all cards
      postersNotifier.value = urls;

      debugPrint("✅ PosterManager: Loaded ${urls.length} posters.");
    } catch (e) {
      debugPrint("❌ PosterManager Error: $e");
    } finally {
      _isFetching = false;
    }
  }
}

class QuoteCard extends StatefulWidget {
  final String quote;
  final String author;
  final String category;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final bool isFavorite;
  final bool isBookmarked;
  final VoidCallback? onFavorite;
  final VoidCallback? onBookmark;
  final VoidCallback? onLongPress;
  final double percentX;
  final double percentY;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.author,
    required this.category,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    this.isFavorite = false,
    this.isBookmarked = false,
    this.onFavorite,
    this.onBookmark,
    this.onLongPress,
    this.percentX = 0.0,
    this.percentY = 0.0,
  });

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  // Default fallback image
  static const String _fallbackUrl = "https://raw.githubusercontent.com/sudoadi/QuoteVault/refs/heads/main/posters/poster%20(1).png";

  @override
  void initState() {
    super.initState();

    _heartController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300)
    );
    _heartScale = Tween<double>(begin: 0.0, end: 1.2).animate(
        CurvedAnimation(parent: _heartController, curve: Curves.elasticOut)
    );

    // Trigger the fetch if needed
    PosterManager().fetchPosters();
  }

  // Helper to pick a consistent image for this quote
  String _getUniqueImage(List<String> posters) {
    if (posters.isEmpty) return _fallbackUrl;
    // Use hash to ensure the same quote always gets the same image from the list
    final int index = widget.quote.hashCode.abs() % posters.length;
    return posters[index];
  }

  void _handleDoubleTap() {
    widget.onFavorite?.call();
    _heartController.forward(from: 0.0).then((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      _heartController.reverse();
    });
  }

  void _openShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuoteShareSheet(
        quote: widget.quote,
        author: widget.author,
        accentColor: widget.accentColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine 3D tilt colors
    Color? overlayColor;
    double opacity = 0.0;
    if (widget.percentX.abs() > 0 || widget.percentY.abs() > 0) {
      if (widget.percentX > 0 && widget.percentY < 0) {
        overlayColor = Colors.redAccent;
      } else if (widget.percentX > 0 && widget.percentY > 0) {
        overlayColor = Colors.greenAccent;
      } else {
        overlayColor = Colors.grey;
      }
      opacity = (widget.percentX.abs() + widget.percentY.abs()).clamp(0.0, 0.3);
    }

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        children: [
          // 1. MAIN CARD SHAPE
          Container(
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 2. BACKGROUND IMAGE (Reactive!)
                  // Listens to the PosterManager. If list updates, this rebuilds.
                  ValueListenableBuilder<List<String>>(
                    valueListenable: PosterManager().postersNotifier,
                    builder: (context, posters, _) {
                      final imageUrl = _getUniqueImage(posters);

                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        // Smooth Fade In to prevent "pop"
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(color: widget.cardColor),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(color: widget.cardColor);
                        },
                      );
                    },
                  ),

                  // 3. FROSTED GLASS & GRADIENT
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 250,
                    child: Stack(
                      children: [
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.4),
                                    Colors.black.withOpacity(0.9),
                                  ],
                                  stops: const [0.0, 0.3, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. TOP BAR
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Text(
                        widget.category.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: widget.onBookmark,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                          color: widget.isBookmarked ? widget.accentColor : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  // 5. MAIN CONTENT
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 90,
                    top: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: ValueListenableBuilder<double>(
                              valueListenable: AppSettings().quoteFontSizeNotifier,
                              builder: (context, scale, child) {
                                return Text(
                                  '"${widget.quote}"',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.notoSans(
                                    color: Colors.white,
                                    fontSize: 24 * scale,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "- ${widget.author}",
                          style: GoogleFonts.spaceMono(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 6. BOTTOM ACTIONS
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _openShareSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Share",
                                  style: GoogleFonts.spaceMono(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            widget.onFavorite?.call();
                            _heartController.forward(from: 0.0).then((_) => _heartController.reverse());
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isFavorite ? Colors.white : Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                              color: widget.isFavorite ? widget.accentColor : Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 7. ANIMATION
                  Center(
                    child: ScaleTransition(
                      scale: _heartScale,
                      child: const Icon(Icons.favorite, color: Colors.white, size: 100),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (overlayColor != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(color: overlayColor.withOpacity(opacity)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }
}