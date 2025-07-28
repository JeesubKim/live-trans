import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  // Settings keys
  static const String _debugLoggingKey = 'debug_logging_enabled';
  static const String _fontSizeKey = 'font_size';
  static const String _selectedLanguageKey = 'selected_language';
  static const String _selectedModelKey = 'selected_model';
  static const String _waveformDisplayKey = 'waveform_display_enabled';

  SharedPreferences? _prefs;

  // Initialize settings
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Debug logging
  bool get debugLoggingEnabled => _prefs?.getBool(_debugLoggingKey) ?? false;
  Future<void> setDebugLogging(bool enabled) async {
    await _prefs?.setBool(_debugLoggingKey, enabled);
  }

  // Font size
  double get fontSize => _prefs?.getDouble(_fontSizeKey) ?? 72.0;
  Future<void> setFontSize(double size) async {
    await _prefs?.setDouble(_fontSizeKey, size);
  }

  // Selected language
  String get selectedLanguage => _prefs?.getString(_selectedLanguageKey) ?? 'English (US)';
  Future<void> setSelectedLanguage(String language) async {
    await _prefs?.setString(_selectedLanguageKey, language);
  }

  // Selected model
  String get selectedModel => _prefs?.getString(_selectedModelKey) ?? 'Device Default';
  Future<void> setSelectedModel(String model) async {
    await _prefs?.setString(_selectedModelKey, model);
  }

  // Waveform display
  bool get waveformDisplayEnabled => _prefs?.getBool(_waveformDisplayKey) ?? true;
  Future<void> setWaveformDisplay(bool enabled) async {
    await _prefs?.setBool(_waveformDisplayKey, enabled);
  }

  // Export all settings
  Map<String, dynamic> exportSettings() {
    return {
      'debugLogging': debugLoggingEnabled,
      'fontSize': fontSize,
      'selectedLanguage': selectedLanguage,
      'selectedModel': selectedModel,
      'waveformDisplay': waveformDisplayEnabled,
    };
  }

  // Import settings
  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings['debugLogging'] != null) {
      await setDebugLogging(settings['debugLogging']);
    }
    if (settings['fontSize'] != null) {
      await setFontSize(settings['fontSize']);
    }
    if (settings['selectedLanguage'] != null) {
      await setSelectedLanguage(settings['selectedLanguage']);
    }
    if (settings['selectedModel'] != null) {
      await setSelectedModel(settings['selectedModel']);
    }
    if (settings['waveformDisplay'] != null) {
      await setWaveformDisplay(settings['waveformDisplay']);
    }
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await setDebugLogging(false);
    await setFontSize(72.0);
    await setSelectedLanguage('English (US)');
    await setSelectedModel('Device Default');
    await setWaveformDisplay(true);
  }
}