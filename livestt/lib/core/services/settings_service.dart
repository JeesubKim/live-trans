import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/settings.dart';

/// Service for managing application settings
class SettingsService {
  static const String _settingsFileName = 'app_settings.json';
  
  String? _appDocumentsPath;
  AppSettings? _cachedSettings;
  bool _isInitialized = false;
  
  final StreamController<AppSettings> _settingsController = StreamController<AppSettings>.broadcast();
  
  /// Stream of settings changes
  Stream<AppSettings> get settingsStream => _settingsController.stream;
  
  /// Current settings (returns default if not loaded)
  AppSettings get settings => _cachedSettings ?? AppSettings.defaultSettings();

  /// Initialize the settings service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // TODO: Get actual app documents directory
      // For now, use current directory for simulation
      _appDocumentsPath = Directory.current.path;
      
      // Load existing settings
      await _loadSettingsFromFile();
      
      _isInitialized = true;
    } catch (e) {
      // If loading fails, use default settings
      _cachedSettings = AppSettings.defaultSettings();
      _isInitialized = true;
    }
  }

  /// Update STT settings
  Future<void> updateSttSettings(SttSettings newSttSettings) async {
    await _ensureInitialized();
    
    final updatedSettings = settings.copyWith(sttSettings: newSttSettings);
    await _saveSettings(updatedSettings);
  }

  /// Update recording settings
  Future<void> updateRecordingSettings(RecordingSettings newRecordingSettings) async {
    await _ensureInitialized();
    
    final updatedSettings = settings.copyWith(recordingSettings: newRecordingSettings);
    await _saveSettings(updatedSettings);
  }

  /// Update display settings
  Future<void> updateDisplaySettings(DisplaySettings newDisplaySettings) async {
    await _ensureInitialized();
    
    final updatedSettings = settings.copyWith(displaySettings: newDisplaySettings);
    await _saveSettings(updatedSettings);
  }

  /// Update all settings at once
  Future<void> updateAllSettings(AppSettings newSettings) async {
    await _ensureInitialized();
    await _saveSettings(newSettings);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _ensureInitialized();
    await _saveSettings(AppSettings.defaultSettings());
  }

  /// Export settings as JSON string
  Future<String> exportSettings() async {
    await _ensureInitialized();
    return jsonEncode(settings.toJson());
  }

  /// Import settings from JSON string
  Future<void> importSettings(String jsonString) async {
    await _ensureInitialized();
    
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final importedSettings = AppSettings.fromJson(jsonData);
      await _saveSettings(importedSettings);
    } catch (e) {
      throw SettingsException('Failed to import settings: Invalid JSON format', e);
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _settingsController.close();
    _isInitialized = false;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<void> _saveSettings(AppSettings newSettings) async {
    try {
      _cachedSettings = newSettings;
      await _saveSettingsToFile();
      _settingsController.add(newSettings);
    } catch (e) {
      throw SettingsException('Failed to save settings', e);
    }
  }

  Future<void> _loadSettingsFromFile() async {
    try {
      final file = File('$_appDocumentsPath/$_settingsFileName');
      
      if (!await file.exists()) {
        // No existing settings file, use defaults
        _cachedSettings = AppSettings.defaultSettings();
        await _saveSettingsToFile(); // Create initial settings file
        return;
      }
      
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      _cachedSettings = AppSettings.fromJson(jsonData);
    } catch (e) {
      // If file is corrupted, use defaults
      _cachedSettings = AppSettings.defaultSettings();
      await _saveSettingsToFile(); // Overwrite corrupted file
    }
  }

  Future<void> _saveSettingsToFile() async {
    try {
      final file = File('$_appDocumentsPath/$_settingsFileName');
      
      final jsonData = {
        'version': '1.0',
        'lastModified': DateTime.now().toIso8601String(),
        ..._cachedSettings!.toJson(),
      };
      
      final jsonString = jsonEncode(jsonData);
      await file.writeAsString(jsonString);
    } catch (e) {
      throw SettingsException('Failed to save settings to file', e);
    }
  }
}

/// Exception thrown by settings service
class SettingsException implements Exception {
  final String message;
  final dynamic originalError;

  SettingsException(this.message, [this.originalError]);

  @override
  String toString() => 'SettingsException: $message';
}