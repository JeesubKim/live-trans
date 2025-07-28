import 'dart:async';
import '../../../services/speech_to_text_service.dart';
import '../../../services/subtitle_display_manager.dart';
import '../../../utils/debug_logger.dart';
import '../interfaces/audio_data_types.dart';
import '../interfaces/i_audio_recorder.dart';
import 'base_audio_recorder.dart';

/// Speech-to-Text based audio recorder
/// New implementation to avoid cache issues
class SpeechAudioRecorder extends BaseAudioRecorder {
  final SpeechToTextService _sttService;
  late final SubtitleDisplayManager _subtitleManager;
  
  // STT callback state
  double _lastAmplitude = 0.1;
  DateTime? _lastSignalUpdate;
  
  SpeechAudioRecorder(this._sttService) {
    // Create a subtitle manager for this recorder
    _subtitleManager = SubtitleDisplayManager();
  }
  
  @override
  Future<bool> hasPermission() async {
    return true;
  }
  
  @override
  Future<bool> requestPermission() async {
    return true;
  }
  
  @override
  Future<void> _startRecordingImpl() async {
    try {
      DebugLogger.info('🎤 SpeechAudioRecorder._startRecordingImpl called');
      
      // Initialize STT service if needed
      if (!_sttService.isInitialized) {
        DebugLogger.info('Initializing STT service...');
        await _sttService.initialize();
      }
      
      // Setup STT callbacks
      DebugLogger.info('Setting up STT callbacks...');
      _setupSTTCallbacks();
      
      // Start STT with subtitle manager
      DebugLogger.info('Starting STT listening...');
      await _sttService.startListening(subtitleManager: _subtitleManager);
      
      DebugLogger.info('✅ Speech Audio Recorder started successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to start Speech Audio Recorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> _pauseRecordingImpl() async {
    try {
      DebugLogger.info('⏸️ Pausing Speech Audio Recorder...');
      await _sttService.stopListening();
      DebugLogger.info('✅ Speech Audio Recorder paused');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to pause Speech Audio Recorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> _resumeRecordingImpl() async {
    try {
      DebugLogger.info('▶️ Resuming Speech Audio Recorder...');
      _setupSTTCallbacks();
      await _sttService.startListening(subtitleManager: _subtitleManager);
      DebugLogger.info('✅ Speech Audio Recorder resumed');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to resume Speech Audio Recorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> _stopRecordingImpl() async {
    try {
      DebugLogger.info('⏹️ Stopping Speech Audio Recorder...');
      await _sttService.stopListening();
      _clearSTTCallbacks();
      DebugLogger.info('✅ Speech Audio Recorder stopped');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to stop Speech Audio Recorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> _disposeImpl() async {
    try {
      DebugLogger.info('🗑️ Disposing Speech Audio Recorder...');
      _clearSTTCallbacks();
      await _sttService.dispose();
      _subtitleManager.dispose();
      DebugLogger.info('✅ Speech Audio Recorder disposed');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to dispose Speech Audio Recorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  void onSamplingTick() {
    // Send Signal data on sampling tick
    if (state == RecordingState.recording) {
      final now = DateTime.now();
      
      // Check if we have recent STT signal (within 200ms)
      final hasRecentSignal = _lastSignalUpdate != null && 
                              now.difference(_lastSignalUpdate!).inMilliseconds < 200;
      
      double amplitude = _lastAmplitude;
      
      // Use baseline if no recent signal or very quiet
      if (!hasRecentSignal || amplitude <= 0.15) {
        amplitude = 0.005; // Quiet state baseline
      }
      
      // Publish Signal data
      final signalData = SignalData(
        amplitude: amplitude,
        timestamp: now,
        metadata: {
          'source': 'speech_stt',
          'has_recent_signal': hasRecentSignal,
        },
      );
      
      publishSignalData(signalData);
    }
  }
  
  /// Setup STT callbacks
  void _setupSTTCallbacks() {
    DebugLogger.info('🔧 Setting up STT callbacks...');
    
    // Sound level callback (for Signal data)
    _sttService.onSoundLevelChanged = (level) {
      // Convert STT sound level to amplitude
      double amplitude;
      
      if (level <= 0.5) {
        amplitude = 0.1; // Minimum baseline
      } else if (level >= 8.0) {
        amplitude = 1.0; // Maximum
      } else {
        // Map 0.5~8.0 range to 0.1~1.0
        final normalizedLevel = (level - 0.5) / 7.5;
        amplitude = (normalizedLevel * 0.9 + 0.1).clamp(0.1, 1.0);
      }
      
      _lastAmplitude = amplitude;
      _lastSignalUpdate = DateTime.now();
      
      DebugLogger.log('🎵 STT Level: $level → Amplitude: ${amplitude.toStringAsFixed(2)}');
    };
    
    // Error callback
    _sttService.onError = (error) {
      DebugLogger.error('🚨 STT Error: $error');
      // Propagate error to all Observees
      for (final observee in observees) {
        observee.onError(error, StackTrace.current);
      }
    };
    
    // Status change callback
    _sttService.onListeningStatusChanged = (isListening) {
      DebugLogger.info('🎤 STT listening status changed: $isListening');
    };
    
    DebugLogger.info('✅ STT callbacks setup complete');
  }
  
  /// Clear STT callbacks
  void _clearSTTCallbacks() {
    DebugLogger.info('🧹 Clearing STT callbacks...');
    _sttService.onSoundLevelChanged = null;
    _sttService.onError = null;
    _sttService.onListeningStatusChanged = null;
    DebugLogger.info('✅ STT callbacks cleared');
  }
  
  /// Get the subtitle manager for external access
  SubtitleDisplayManager get subtitleManager => _subtitleManager;
}