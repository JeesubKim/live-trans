import 'dart:async';
import '../../../services/speech_to_text_service.dart';
import '../../../services/subtitle_display_manager.dart';
import '../../../utils/debug_logger.dart';
import '../interfaces/audio_data_types.dart';
import '../interfaces/i_audio_recorder.dart';
import 'base_audio_recorder.dart';

/// STT-based audio recorder implementation
/// Wraps SpeechToTextService for the new pipeline architecture  
class STTAudioRecorder extends BaseAudioRecorder {
  final SpeechToTextService _sttService;
  late final SubtitleDisplayManager _subtitleManager;
  
  // STT callback state
  double _lastAmplitude = 0.1;
  DateTime? _lastSignalUpdate;
  
  STTAudioRecorder(this._sttService) {
    // Create a subtitle manager for this recorder
    _subtitleManager = SubtitleDisplayManager();
  }
  
  @override
  Future<bool> hasPermission() async {
    // For now, assume permission is available since STT handles its own permissions
    return true;
  }
  
  @override
  Future<bool> requestPermission() async {
    // For now, assume permission is granted since STT handles its own permissions
    return true;
  }
  
  @override
  Future<void> _startRecordingImpl() async {
    try {
      DebugLogger.info('STTAudioRecorder._startRecordingImpl called');
      
      // Initialize STT service if needed
      if (!_sttService.isInitialized) {
        await _sttService.initialize();
      }
      
      // Setup STT callbacks
      _setupSTTCallbacks();
      
      // Start STT with subtitle manager
      await _sttService.startListening(subtitleManager: _subtitleManager);
      
      DebugLogger.info('STT Audio Recorder started successfully');
    } catch (e) {
      DebugLogger.error('Failed to start STT Audio Recorder: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> _pauseRecordingImpl() async {
    try {
      // STT doesn't have pause, so we stop and restart approach
      await _sttService.stopListening();
      DebugLogger.info('STT Audio Recorder paused (stopped)');
    } catch (e) {
      DebugLogger.error('Failed to pause STT Audio Recorder: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> _resumeRecordingImpl() async {
    try {
      // Restart STT
      _setupSTTCallbacks();
      await _sttService.startListening(subtitleManager: _subtitleManager);
      DebugLogger.info('STT Audio Recorder resumed (restarted)');
    } catch (e) {
      DebugLogger.error('Failed to resume STT Audio Recorder: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> _stopRecordingImpl() async {
    try {
      await _sttService.stopListening();
      _clearSTTCallbacks();
      DebugLogger.info('STT Audio Recorder stopped');
    } catch (e) {
      DebugLogger.error('Failed to stop STT Audio Recorder: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> _disposeImpl() async {
    try {
      _clearSTTCallbacks();
      await _sttService.dispose();
      _subtitleManager.dispose(); // This returns void, not Future<void>
      DebugLogger.info('STT Audio Recorder disposed');
    } catch (e) {
      DebugLogger.error('Failed to dispose STT Audio Recorder: $e');
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
          'source': 'stt',
          'has_recent_signal': hasRecentSignal,
        },
      );
      
      publishSignalData(signalData);
    }
  }
  
  /// Setup STT callbacks
  void _setupSTTCallbacks() {
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
      
      DebugLogger.log('STT Level: $level → Amplitude: ${amplitude.toStringAsFixed(2)}');
    };
    
    // Error callback
    _sttService.onError = (error) {
      DebugLogger.error('STT Error: $error');
      // Propagate error to all Observees
      for (final observee in observees) {
        observee.onError(error, StackTrace.current);
      }
    };
    
    // Status change callback
    _sttService.onListeningStatusChanged = (isListening) {
      DebugLogger.info('STT listening status changed: $isListening');
    };
  }
  
  /// Clear STT callbacks
  void _clearSTTCallbacks() {
    _sttService.onSoundLevelChanged = null;
    _sttService.onError = null;
    _sttService.onListeningStatusChanged = null;
  }
  
  /// Get the subtitle manager for external access
  SubtitleDisplayManager get subtitleManager => _subtitleManager;
}