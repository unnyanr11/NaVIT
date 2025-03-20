import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  late Locale _locale; // Ensure _locale is always defined

  LanguageProvider({required String initialLanguage}) {
    _locale = Locale(initialLanguage.isNotEmpty ? initialLanguage : 'en', '');
  }

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode; // Getter for language code

  Future<void> changeLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return; // Avoid unnecessary updates

    _locale = Locale(languageCode, '');
    notifyListeners();

    // Save selected language in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
  }
}
