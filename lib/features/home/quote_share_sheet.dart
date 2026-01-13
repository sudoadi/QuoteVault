import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

class QuoteShareSheet extends StatefulWidget {
  final String quote;
  final String author;
  final Color accentColor;

  const QuoteShareSheet({
    super.key,
    required this.quote,
    required this.author,
    required this.accentColor,
  });

  @override
  State<QuoteShareSheet> createState() => _QuoteShareSheetState();
}

class _QuoteShareSheetState extends State<QuoteShareSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final PageController _pageController = PageController(viewportFraction: 0.65);

  int _selectedIndex = 0;
  bool _isProcessing = false;

  final List<String> _styles = ['Vibrant', 'Minimal', 'Terminal', 'Elegant'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "SHARE QUOTE",
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // === TEMPLATE CAROUSEL ===
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _styles.length,
              onPageChanged: (index) => setState(() => _selectedIndex = index),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedIndex;
                return AnimatedScale(
                  scale: isSelected ? 1.0 : 0.85,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isSelected ? 1.0 : 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: isSelected
                            ? [BoxShadow(color: widget.accentColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                            : [],
                      ),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 1080,
                          height: 1350,
                          child: _getStyleWidget(index),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 15),

          Text(
            _styles[_selectedIndex].toUpperCase(),
            style: GoogleFonts.spaceMono(color: widget.accentColor, fontWeight: FontWeight.bold),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.copy_rounded,
                  label: "Copy Text",
                  onTap: _shareText,
                ),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: "Share Image",
                  isPrimary: true,
                  onTap: () => _exportImage(share: true),
                ),
                _buildActionButton(
                  icon: Icons.download_rounded,
                  label: "Save Image",
                  onTap: () => _exportImage(share: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, bool isPrimary = false}) {
    // ... (Keep existing implementation)
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPrimary ? widget.accentColor : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: _isProcessing && isPrimary
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(icon, color: isPrimary ? Colors.white : Colors.white70, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.spaceMono(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
    );
  }

  // === STYLES WITH WATERMARK ===

  Widget _getStyleWidget(int index) {
    switch (index) {
      case 0: return _styleVibrant();
      case 1: return _styleMinimal();
      case 2: return _styleTerminal();
      case 3: return _styleElegant();
      default: return _styleVibrant();
    }
  }

  // Helper to build the watermark widget
  Widget _buildWatermark(Color color) {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          "QuoteVault",
          style: GoogleFonts.spaceMono(
              fontSize: 24,
              color: color,
              letterSpacing: 2,
              fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }

  Widget _styleVibrant() {
    return Container(
      padding: const EdgeInsets.all(80),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.accentColor, widget.accentColor.withOpacity(0.6)],
        ),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.format_quote_rounded, size: 150, color: Colors.white38),
              const SizedBox(height: 40),
              Text(
                widget.quote,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
              ),
              const SizedBox(height: 60),
              Container(height: 6, width: 120, color: Colors.white),
              const SizedBox(height: 40),
              Text(widget.author.toUpperCase(), style: GoogleFonts.spaceMono(fontSize: 32, color: Colors.white70, letterSpacing: 4)),
            ],
          ),
          _buildWatermark(Colors.white.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _styleMinimal() {
    return Container(
      padding: const EdgeInsets.all(80),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F0E9),
        borderRadius: BorderRadius.circular(60),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("“", style: GoogleFonts.playfairDisplay(fontSize: 250, color: Colors.black12, height: 0.4)),
              Text(
                widget.quote,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(fontSize: 65, color: const Color(0xFF2D2D2D), fontStyle: FontStyle.italic, height: 1.2),
              ),
              const SizedBox(height: 60),
              Text("— ${widget.author}", style: GoogleFonts.lato(fontSize: 34, color: const Color(0xFF555555), fontWeight: FontWeight.bold)),
            ],
          ),
          _buildWatermark(Colors.black26),
        ],
      ),
    );
  }

  Widget _styleTerminal() {
    return Container(
      padding: const EdgeInsets.all(80),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: widget.accentColor, width: 6),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: widget.accentColor, size: 70),
                  const SizedBox(width: 30),
                  Text("daily_truth.exe", style: GoogleFonts.spaceMono(color: widget.accentColor, fontSize: 35)),
                ],
              ),
              const Spacer(),
              Text("> ${widget.quote}", style: GoogleFonts.spaceMono(fontSize: 50, color: Colors.white, height: 1.4)),
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                color: widget.accentColor,
                child: Text(widget.author, style: GoogleFonts.spaceMono(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
            ],
          ),
          _buildWatermark(widget.accentColor.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _styleElegant() {
    return Container(
      padding: const EdgeInsets.all(80),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(60),
      ),
      child: Stack(
        children: [
          Positioned(right: 0, bottom: 0, child: Icon(Icons.format_quote, size: 500, color: Colors.white.withOpacity(0.03))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.quote.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(fontSize: 110, color: Colors.white, height: 0.9, letterSpacing: 2)),
                const SizedBox(height: 60),
                Text(widget.author, style: GoogleFonts.firaCode(fontSize: 32, color: widget.accentColor)),
              ],
            ),
          ),
          _buildWatermark(Colors.white.withOpacity(0.3)),
        ],
      ),
    );
  }

  // === EXPORT LOGIC (Keep existing) ===
  Future<void> _shareText() async {
    await Share.share('"${widget.quote}"\n\n- ${widget.author}\n\nShared via QuoteVault');
    if (mounted) Navigator.pop(context);
  }

  Future<void> _exportImage({required bool share}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        Container(
          width: 400,
          height: 500,
          decoration: BoxDecoration(
            color: _selectedIndex == 1 ? const Color(0xFFF2F0E9) : Colors.black,
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1080,
              height: 1350,
              child: _getStyleWidget(_selectedIndex),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 50),
        pixelRatio: 2.0,
      );

      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final fileName = 'quotevault_${DateTime.now().millisecondsSinceEpoch}.png';
        final imagePath = await File('${directory.path}/$fileName').create();
        await imagePath.writeAsBytes(imageBytes);

        if (share) {
          await Share.shareXFiles([XFile(imagePath.path)], text: "QuoteVault Daily");
        } else {
          await Gal.putImage(imagePath.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Saved to Gallery", style: GoogleFonts.spaceMono(color: Colors.white)), backgroundColor: widget.accentColor),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error exporting: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}