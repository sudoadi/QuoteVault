import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http; // Make sure http is in pubspec.yaml

class WidgetManager {
  static const String _androidWidgetName = 'QuoteWidgetProvider';

  /// Downloads a random image from the list and updates the widget
  static Future<void> updateWidget({
    required String quote,
    required String author,
    required List<String> posterUrls
  }) async {
    try {
      String? localImagePath;

      // 1. Pick and Download a Random Image
      if (posterUrls.isNotEmpty) {
        final randomUrl = posterUrls[Random().nextInt(posterUrls.length)];
        localImagePath = await _downloadImage(randomUrl);
      }

      // 2. Save Data to Native Storage
      await HomeWidget.saveWidgetData<String>('quote_text', quote);
      await HomeWidget.saveWidgetData<String>('quote_author', author);

      if (localImagePath != null) {
        await HomeWidget.saveWidgetData<String>('background_path', localImagePath);
      }

      // 3. Trigger Update
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: 'QuoteWidget',
      );
    } catch (e) {
      debugPrint("❌ Error updating widget: $e");
    }
  }

  /// Helper: Downloads image to app directory
  static Future<String?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationSupportDirectory();
        final filePath = '${directory.path}/widget_background.png';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint("❌ Error downloading widget image: $e");
    }
    return null;
  }
}