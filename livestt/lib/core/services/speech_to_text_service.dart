import 'dart:async';
import '../models/caption.dart';
import '../models/settings.dart';

/// Abstract interface for Speech-to-Text services
abstract class SpeechToTextService {
  /// Stream of captions as they are recognized
  Stream<Caption> get captionStream;
  
  /// Stream of audio levels for waveform visualization
  Stream<double> get audioLevelStream;
  
  /// Current recognition status
  Stream<SttStatus> get statusStream;
  
  /// Whether the service is currently active
  bool get isActive;
  
  /// Whether the service is currently listening
  bool get isListening;
  
  /// Current settings
  SttSettings get settings;

  /// Initialize the service with given settings
  Future<void> initialize(SttSettings settings);
  
  /// Start listening for speech
  Future<void> startListening();
  
  /// Stop listening
  Future<void> stopListening();
  
  /// Pause listening (can be resumed)
  Future<void> pauseListening();
  
  /// Resume listening after pause
  Future<void> resumeListening();
  
  /// Update settings while running
  Future<void> updateSettings(SttSettings newSettings);
  
  /// Check if the device supports the given language
  Future<bool> isLanguageSupported(SttLanguage language);
  
  /// Get available languages on this device
  Future<List<SttLanguage>> getAvailableLanguages();
  
  /// Clean up resources
  Future<void> dispose();
}

/// Status of the STT service
enum SttStatus {
  uninitialized,
  initializing,
  ready,
  listening,
  paused,
  processing,
  error,
  disposed,
}

/// Exception thrown by STT services
class SttException implements Exception {
  final String message;
  final SttErrorType type;
  final dynamic originalError;

  SttException(this.message, this.type, [this.originalError]);

  @override
  String toString() => 'SttException: $message (${type.name})';
}

enum SttErrorType {
  permissionDenied,
  microphoneNotAvailable,
  networkError,
  languageNotSupported,
  modelNotAvailable,
  initializationFailed,
  recognitionFailed,
  unknown,
}

/// Factory for creating STT service instances
class SttServiceFactory {
  static SpeechToTextService createService(SttModel model) {
    switch (model) {
      case SttModel.deviceDefault:
        return WhisperSttService(); // Using generic implementation
      default:
        throw UnsupportedError('STT model ${model.displayName} is not supported');
    }
  }
  
  static Future<List<SttModel>> getAvailableModels() async {
    // Return only device default model
    return [SttModel.deviceDefault];
  }
}

/// Whisper-based STT implementation
class WhisperSttService implements SpeechToTextService {
  final StreamController<Caption> _captionController = StreamController<Caption>.broadcast();
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  final StreamController<SttStatus> _statusController = StreamController<SttStatus>.broadcast();
  
  SttStatus _status = SttStatus.uninitialized;
  SttSettings? _settings;
  Timer? _simulationTimer;
  bool _isActive = false;
  bool _isListening = false;
  
  @override
  Stream<Caption> get captionStream => _captionController.stream;
  
  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  @override
  Stream<SttStatus> get statusStream => _statusController.stream;
  
  @override
  bool get isActive => _isActive;
  
  @override
  bool get isListening => _isListening;
  
  @override
  SttSettings get settings => _settings ?? SttSettings.defaultSettings();

  @override
  Future<void> initialize(SttSettings settings) async {
    _updateStatus(SttStatus.initializing);
    _settings = settings;
    
    try {
      // TODO: Initialize actual Whisper STT service
      // For now, simulate initialization
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isActive = true;
      _updateStatus(SttStatus.ready);
    } catch (e) {
      _updateStatus(SttStatus.error);
      throw SttException('Failed to initialize STT service', SttErrorType.initializationFailed, e);
    }
  }

  @override
  Future<void> startListening() async {
    if (!_isActive) {
      throw SttException('Service not initialized', SttErrorType.initializationFailed);
    }
    
    _isListening = true;
    _updateStatus(SttStatus.listening);
    
    // TODO: Start actual STT listening
    // For now, simulate recognition with timer
    _startSimulation();
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _simulationTimer?.cancel();
    _updateStatus(SttStatus.ready);
  }

  @override
  Future<void> pauseListening() async {
    if (_isListening) {
      _isListening = false;
      _simulationTimer?.cancel();
      _updateStatus(SttStatus.paused);
    }
  }

  @override
  Future<void> resumeListening() async {
    if (_status == SttStatus.paused) {
      _isListening = true;
      _updateStatus(SttStatus.listening);
      _startSimulation();
    }
  }

  @override
  Future<void> updateSettings(SttSettings newSettings) async {
    _settings = newSettings;
    // TODO: Apply new settings to running STT service
  }

  @override
  Future<bool> isLanguageSupported(SttLanguage language) async {
    // TODO: Check actual language support
    return [SttLanguage.english].contains(language);
  }

  @override
  Future<List<SttLanguage>> getAvailableLanguages() async {
    // TODO: Get actual available languages
    return [SttLanguage.english];
  }

  @override
  Future<void> dispose() async {
    _simulationTimer?.cancel();
    _isActive = false;
    _isListening = false;
    _updateStatus(SttStatus.disposed);
    
    await _captionController.close();
    await _audioLevelController.close();
    await _statusController.close();
  }

  void _updateStatus(SttStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _startSimulation() {
    // Simulate audio levels for waveform
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      
      // Generate random audio level
      final level = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
      _audioLevelController.add(level);
    });

    // Simulate caption recognition
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      
      // Generate sample caption
      final sampleTexts = [
        'This is a sample caption for demonstration purposes.',
        'Real-time speech recognition is working properly.',
        'You can see the captions appearing as you speak.',
        'The waveform shows the audio input levels.',
        'Multiple languages are supported in this system.',
      ];
      
      final randomText = sampleTexts[timer.tick % sampleTexts.length];
      
      final caption = Caption(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: randomText,
        timestamp: DateTime.now(),
        startTime: Duration(seconds: timer.tick * 3),
        confidence: 0.85 + (timer.tick % 3) * 0.05,
        isFinal: true,
        language: settings.language.code,
      );
      
      _captionController.add(caption);
    });
  }
}