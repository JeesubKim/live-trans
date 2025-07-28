/// Language mapping utility for consistent STT locale handling
class LanguageMapping {
  static const Map<String, String> _languageToLocale = {
    'Korean': 'ko',
    'English': 'en',
    'English (US)': 'en',
    'Japanese': 'ja',
    'Chinese': 'zh',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
  };

  /// Map language display name to locale prefix
  static String getLocalePrefix(String languageName) {
    // Try exact match first
    final exactMatch = _languageToLocale[languageName];
    if (exactMatch != null) {
      return exactMatch;
    }
    
    // Try partial match for languages that contain keywords
    for (final entry in _languageToLocale.entries) {
      if (languageName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Default to English since it's more universally available
    return 'en';
  }

  /// Get all supported language display names
  static List<String> get supportedLanguages => _languageToLocale.keys.toList();

  /// Check if a language is supported
  static bool isSupported(String languageName) {
    return _languageToLocale.containsKey(languageName) ||
           _languageToLocale.keys.any((key) => languageName.contains(key));
  }
}