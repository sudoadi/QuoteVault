import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  // Notifiers for reactive UI updates
  final ValueNotifier<double> quoteFontSizeNotifier = ValueNotifier(1.0);
  final ValueNotifier<double> uiFontSizeNotifier = ValueNotifier(1.0);

  void updateQuoteFontSize(double val) {
    quoteFontSizeNotifier.value = val;
  }

  void updateUiFontSize(double val) {
    uiFontSizeNotifier.value = val;
  }
}