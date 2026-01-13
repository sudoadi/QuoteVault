import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'quote_share_sheet.dart'; // <--- Kept Sharing Import
import '../../managers/app_settings.dart'; // <--- New Import

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
  }

  void _handleDoubleTap() {
    widget.onFavorite?.call();
    _heartController.forward(from: 0.0).then((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      _heartController.reverse();
    });
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

  // === PRESERVED: Share Sheet Logic ===
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
    final catColor = _getCategoryColor(widget.category);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [catColor, catColor.withOpacity(0.4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -50,
                          bottom: -50,
                          child: Icon(
                            Icons.format_quote_rounded,
                            size: 200,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Text(
                              widget.category.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: catColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: widget.onBookmark,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                                color: widget.isBookmarked ? widget.accentColor : Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _openShareSheet, // <--- PRESERVED: Share Action
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  widget.onFavorite?.call();
                                  _heartController.forward(from: 0.0).then((_) => _heartController.reverse());
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                      widget.isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                                      color: widget.isFavorite ? widget.accentColor : Colors.white,
                                      size: 24
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: ScaleTransition(
                            scale: _heartScale,
                            child: const Icon(Icons.favorite, color: Colors.white, size: 100),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              "DAILY TRUTH",
                              style: GoogleFonts.spaceMono(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      color: widget.cardColor,
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: ValueListenableBuilder<double>( // <--- NEW: Dynamic Font Size Listener
                                  valueListenable: AppSettings().quoteFontSizeNotifier,
                                  builder: (context, scale, child) {
                                    return Text(
                                      '"${widget.quote}"',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.notoSans(
                                        color: widget.textColor,
                                        fontSize: 22 * scale, // <--- Apply Scaling
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_outlined, color: catColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                widget.author,
                                style: GoogleFonts.spaceMono(
                                  color: widget.textColor.withOpacity(0.8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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