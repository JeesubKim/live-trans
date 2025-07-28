import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'subtitle_display_manager.dart';
import '../utils/debug_logger.dart';

class SpeechToTextService {
  static final SpeechToTextService _instance = SpeechToTextService._internal();
  factory SpeechToTextService() => _instance;
  SpeechToTextService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentLocaleId = 'en_US'; // Default English
  
  // Available locales
  List<LocaleName> _availableLocales = [];
  
  // Status callbacks
  Function(bool)? onListeningStatusChanged;
  Function(String)? onError;
  Function(bool)? onInitializationChanged;
  Function(double)? onSoundLevelChanged;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentLocale => _currentLocaleId;
  List<LocaleName> get availableLocales => _availableLocales;

  // Initialize STT service
  Future<bool> initialize() async {
    // Prevent double initialization
    if (_isInitialized) {
      DebugLogger.log('STT already initialized, skipping...');
      return true;
    }
    
    try {
      DebugLogger.info('Initializing Speech-to-Text service...');
      
      // Initialize speech to text
      _isInitialized = await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: false,  // Disable plugin debug logs - we have our own
      );

      if (_isInitialized) {
        // Check permissions
        final hasPermission = await _speechToText.hasPermission;
        DebugLogger.log('STT has permission: $hasPermission');
        
        // Get available locales
        _availableLocales = await _speechToText.locales();
        DebugLogger.info('STT initialized successfully');
        DebugLogger.log('Available locales: ${_availableLocales.length}');
        
        // Print all available locales for debugging
        DebugLogger.info('📋 Available locales (${_availableLocales.length} total):');
        for (final locale in _availableLocales) {
          final isEnglish = locale.localeId.startsWith('en') ? '🇺🇸' : '  ';
          DebugLogger.info('$isEnglish ${locale.localeId}: ${locale.name}');
        }
        
        // Force English locale selection - prioritize English variants
        LocaleName? englishLocale;
        
        // First try en_US specifically
        for (final locale in _availableLocales) {
          if (locale.localeId == 'en_US') {
            englishLocale = locale;
            break;
          }
        }
        
        // If no en_US, try any English variant
        if (englishLocale == null) {
          for (final locale in _availableLocales) {
            if (locale.localeId.startsWith('en')) {
              englishLocale = locale;
              break;
            }
          }
        }
        
        if (englishLocale != null) {
          _currentLocaleId = englishLocale.localeId;
          DebugLogger.info('🇺🇸 Forced English locale: $_currentLocaleId (${englishLocale.name})');
        } else if (_availableLocales.isNotEmpty) {
          _currentLocaleId = _availableLocales.first.localeId;
          DebugLogger.info('⚠️ English not available, using first locale: $_currentLocaleId (${_availableLocales.first.name})');
        } else {
          DebugLogger.warning('No locales available');
        }
      } else {
        DebugLogger.error('Failed to initialize STT service');
      }

      onInitializationChanged?.call(_isInitialized);
      return _isInitialized;
    } catch (e) {
      DebugLogger.error('Error initializing STT: $e');
      _isInitialized = false;
      onInitializationChanged?.call(_isInitialized);
      onError?.call('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  // Start listening for speech
  Future<bool> startListening({
    required SubtitleDisplayManager subtitleManager,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      DebugLogger.warning('STT not initialized');
      onError?.call('Speech recognition not initialized');
      return false;
    }

    // Force stop any existing session to prevent busy error
    if (_isListening || _speechToText.isListening) {
      DebugLogger.log('Existing session detected, force stopping...');
      await _forceStopListening();
      // Minimal delay for fastest restart while ensuring cleanup
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      DebugLogger.info('Starting STT listening...');
      
      final locale = localeId ?? _currentLocaleId;
      DebugLogger.info('🌐 Using locale for STT: $locale (requested: $localeId, current: $_currentLocaleId)');
      
      await _speechToText.listen(
        onResult: (result) => _onSpeechResult(result, subtitleManager),
        localeId: locale,
        listenFor: const Duration(seconds: 60), // Much longer listening
        pauseFor: const Duration(seconds: 30),  // Much longer pause - user sees realtime anyway
        partialResults: true,                   // Get partial results
        onSoundLevelChange: (level) {
          // DebugLogger.info('🎤 Sound level: $level');  // Commented for cleaner logs
          onSoundLevelChanged?.call(level);
        },
        cancelOnError: false,                   // Don't cancel on error
        listenMode: ListenMode.dictation,       // More sensitive mode
      );

      _isListening = true;
      _currentLocaleId = locale;
      onListeningStatusChanged?.call(_isListening);
      DebugLogger.info('STT listening started with locale: $locale');
      return true;
      
    } catch (e) {
      DebugLogger.error('Error starting STT: $e');
      onError?.call('Failed to start speech recognition: $e');
      return false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      DebugLogger.info('Stopping STT listening...');
      await _speechToText.stop();
      _isListening = false;
      onListeningStatusChanged?.call(_isListening);
      DebugLogger.info('STT listening stopped');
    } catch (e) {
      DebugLogger.error('Error stopping STT: $e');
      onError?.call('Error stopping speech recognition: $e');
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      DebugLogger.info('Canceling STT listening...');
      await _speechToText.cancel();
      _isListening = false;
      onListeningStatusChanged?.call(_isListening);
      DebugLogger.info('STT listening canceled');
    } catch (e) {
      DebugLogger.error('Error canceling STT: $e');
    }
  }

  // Force stop listening - more aggressive cleanup
  Future<void> _forceStopListening() async {
    try {
      DebugLogger.info('Force stopping STT...');
      
      // Try cancel first
      if (_speechToText.isListening) {
        await _speechToText.cancel();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Then try stop
      if (_speechToText.isListening) {
        await _speechToText.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Reset internal state regardless
      _isListening = false;
      onListeningStatusChanged?.call(_isListening);
      DebugLogger.info('Force stop completed');
      
    } catch (e) {
      DebugLogger.error('Error in force stop: $e');
      // Reset state even if error occurred
      _isListening = false;
      onListeningStatusChanged?.call(_isListening);
    }
  }

  // Set locale
  Future<bool> setLocale(String localeId) async {
    if (!_isInitialized) return false;

    // Check if locale is available
    final isAvailable = _availableLocales.any((locale) => locale.localeId == localeId);
    if (!isAvailable) {
      DebugLogger.warning('Locale not available: $localeId');
      onError?.call('Language not supported: $localeId');
      return false;
    }

    _currentLocaleId = localeId;
    DebugLogger.info('Locale changed to: $localeId');
    return true;
  }

  // Get locale name from ID
  String getLocaleName(String localeId) {
    final locale = _availableLocales.firstWhere(
      (locale) => locale.localeId == localeId,
      orElse: () => LocaleName(localeId, localeId),
    );
    return locale.name;
  }

  // Handle speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result, SubtitleDisplayManager subtitleManager) {
    DebugLogger.info('📢 STT Result: "${result.recognizedWords}" (final: ${result.finalResult}, confidence: ${result.confidence})');
    
    if (result.recognizedWords.isNotEmpty) {
      try {
        if (result.finalResult) {
          DebugLogger.info('🔒 Final STT result - processing async: "${result.recognizedWords}"');
          // Process final result asynchronously to prevent blocking STT
          _processFinalResultAsync(result.recognizedWords, result.confidence, subtitleManager);
        } else {
          DebugLogger.info('⏳ Partial STT result - updating: "${result.recognizedWords}"');
          // Partial results processed immediately
          subtitleManager.updateRealtimeText(result.recognizedWords);
        }
      } catch (e) {
        DebugLogger.error('❌ Error processing STT result: $e');
      }
    } else {
      DebugLogger.info('🔇 STT result is empty - no recognized words');
    }
  }
  
  // Process final STT result asynchronously to prevent blocking STT callback
  void _processFinalResultAsync(String recognizedWords, double confidence, SubtitleDisplayManager subtitleManager) {
    // Ultra-fast microtask to immediately return control to STT
    Future.microtask(() async {
      try {
        DebugLogger.info('💾 Async processing final result: "$recognizedWords"');
        
        // This processing now runs asynchronously, immediately returning control to STT
        subtitleManager.confirmRealtimeText(finalText: recognizedWords, confidence: confidence);
        
        DebugLogger.info('✅ Final result processing completed asynchronously');
      } catch (e) {
        DebugLogger.error('❌ Error in async final result processing: $e');
      }
    });
  }

  // Handle speech recognition errors
  void _onSpeechError(SpeechRecognitionError error) {
    DebugLogger.log('STT Error: ${error.errorMsg} (permanent: ${error.permanent})');
    
    // Handle common errors gracefully - they're expected in continuous mode
    final normalErrors = [
      'error_speech_timeout',
      'error_no_match', 
      'error_network_timeout',
      'error_client'
    ];
    
    if (normalErrors.contains(error.errorMsg)) {
      DebugLogger.log('STT ${error.errorMsg} - normal for continuous recognition');
      _isListening = false;
      onListeningStatusChanged?.call(_isListening);
      // Don't show these errors to user - they're normal operational states
      return;
    }
    
    // Handle permanent errors
    if (error.permanent) {
      _isListening = false;
      onListeningStatusChanged?.call(_isListening);
      
      // Show user-friendly error messages for permanent errors
      String userMessage = _getUserFriendlyErrorMessage(error.errorMsg);
      onError?.call(userMessage);
    } else {
      // For non-permanent errors, just log them
      DebugLogger.warning('Non-permanent STT error: ${error.errorMsg}');
    }
  }
  
  // Convert technical error messages to user-friendly ones
  String _getUserFriendlyErrorMessage(String errorMsg) {
    switch (errorMsg) {
      case 'error_audio':
        return 'Microphone access issue. Please check permissions.';
      case 'error_network':
        return 'Network connection issue. Please check your internet.';
      case 'error_busy':
        return 'Speech recognition is busy. Please try again.';
      case 'error_insufficient_permissions':
        return 'Microphone permission required for speech recognition.';
      case 'error_recognizer_busy':
        return 'Speech recognizer is busy. Please wait and try again.';
      case 'error_server':
        return 'Server error. Please try again later.';
      default:
        return 'Speech recognition error: $errorMsg';
    }
  }

  // Handle speech recognition status changes
  void _onSpeechStatus(String status) {
    DebugLogger.log('STT Status: $status');
    
    // Update listening status based on STT status
    switch (status) {
      case 'listening':
        if (!_isListening) {
          _isListening = true;
          onListeningStatusChanged?.call(_isListening);
        }
        break;
      case 'notListening':
      case 'done':
        if (_isListening) {
          _isListening = false;
          onListeningStatusChanged?.call(_isListening);
        }
        break;
    }
  }

  // Restart listening (for continuous recognition)
  Future<void> restartListening(SubtitleDisplayManager subtitleManager) async {
    if (!_isInitialized) return;
    
    DebugLogger.info('Restarting STT listening...');
    
    // Cancel current session if running
    if (_isListening) {
      await cancelListening();
    }
    
    // Optimized delay to reduce battery consumption while maintaining responsiveness
    await Future.delayed(const Duration(milliseconds: 500));
    
    await startListening(subtitleManager: subtitleManager);
  }

  // Check if has permission
  Future<bool> hasPermission() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speechToText.hasPermission;
  }

  // Get STT capabilities info
  Map<String, dynamic> getCapabilities() {
    return {
      'isInitialized': _isInitialized,
      'isListening': _isListening,
      'currentLocale': _currentLocaleId,
      'availableLocales': _availableLocales.map((locale) => {
        'id': locale.localeId,
        'name': locale.name,
      }).toList(),
      'hasPermission': _speechToText.hasPermission,
    };
  }

  // Dispose resources
  Future<void> dispose() async {
    DebugLogger.info('Disposing STT service...');
    try {
      // Force stop to ensure complete cleanup
      await _forceStopListening();
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      DebugLogger.error('Error during STT disposal: $e');
    }
    
    onListeningStatusChanged = null;
    onError = null;
    onInitializationChanged = null;
    onSoundLevelChanged = null;
    DebugLogger.info('STT service disposed');
  }
}