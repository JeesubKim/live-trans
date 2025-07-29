import 'dart:async';
import '../../../services/speech_to_text_service.dart';
import '../../../services/subtitle_display_manager.dart';
import '../../../utils/debug_logger.dart';
import '../interfaces/audio_data_types.dart';
import '../interfaces/i_audio_recorder.dart';
import '../interfaces/i_observee.dart';

/// Simple STT recorder - direct implementation of IAudioRecorder
/// Avoids inheritance issues by implementing the interface directly
class SimpleSttRecorder implements IAudioRecorder {
  final SpeechToTextService _sttService;
  SubtitleDisplayManager _subtitleManager;
  
  // Configuration and state
  late AudioRecorderConfig _config;
  final List<IObservee> _observees = [];
  final StreamController<RecordingState> _stateController = StreamController<RecordingState>.broadcast();
  
  RecordingState _state = RecordingState.uninitialized;
  Timer? _samplingTimer;
  Timer? _autoRestartTimer;
  
  // STT callback state
  double _lastAmplitude = 0.1;
  DateTime? _lastSignalUpdate;
  
  // Audio buffering for gap coverage
  final List<double> _audioLevelBuffer = [];
  DateTime? _lastSTTResult;
  bool _hasRecentActivity = false;
  StreamSubscription? _subtitleSubscription;
  
  // STT restart management
  bool _isRestartInProgress = false;
  DateTime? _lastRestartAttempt;
  
  SimpleSttRecorder(this._sttService) : _subtitleManager = SubtitleDisplayManager() {
    // Subscribe to subtitle results to track STT activity
    _subscribeToSubtitleResults();
  }
  
  @override
  RecordingState get state => _state;
  
  @override
  Stream<RecordingState> get stateStream => _stateController.stream;
  
  @override
  AudioRecorderConfig get config => _config;
  
  @override
  List<IObservee> get observees => List.unmodifiable(_observees);
  
  @override
  Future<bool> hasPermission() async {
    return await _sttService.hasPermission();
  }
  
  @override
  Future<bool> requestPermission() async {
    return await _sttService.hasPermission();
  }
  
  @override
  Future<void> initialize(AudioRecorderConfig config) async {
    DebugLogger.info('🔧 SimpleSttRecorder.initialize called');
    _config = config;
    
    // Check STT permission first
    final hasPermission = await _sttService.hasPermission();
    DebugLogger.info('🎤 STT Permission: $hasPermission');
    
    if (!hasPermission) {
      DebugLogger.error('❌ No microphone permission for STT');
      throw Exception('Microphone permission required for speech recognition');
    }
    
    // Initialize all observees
    for (final observee in _observees) {
      await observee.initialize();
    }
    
    _updateState(RecordingState.ready);
    DebugLogger.info('✅ SimpleSttRecorder initialized successfully');
  }
  
  @override
  void addObservee(IObservee observee) {
    if (!_observees.contains(observee)) {
      _observees.add(observee);
      DebugLogger.info('📝 Added observee: ${observee.id}');
    }
  }
  
  @override
  void removeObservee(IObservee observee) {
    _observees.remove(observee);
    DebugLogger.info('🗑️ Removed observee: ${observee.id}');
  }
  
  @override
  List<IObservee> getObserveesByType(ObserveeDataType dataType) {
    return _observees
        .where((observee) => observee.supportedDataTypes.contains(dataType))
        .toList();
  }
  
  @override
  Future<void> startRecording() async {
    DebugLogger.info('🎤 SimpleSttRecorder.startRecording called');
    
    if (_state != RecordingState.ready && _state != RecordingState.stopped) {
      throw StateError('Cannot start recording from state: $_state');
    }
    
    try {
      await _startRecordingImpl();
      _startSamplingTimer();
      _startAutoRestartTimer();
      _updateState(RecordingState.recording);
      DebugLogger.info('✅ SimpleSttRecorder recording started successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to start SimpleSttRecorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> pauseRecording() async {
    DebugLogger.info('⏸️ SimpleSttRecorder.pauseRecording called');
    
    if (_state != RecordingState.recording) {
      throw StateError('Cannot pause recording from state: $_state');
    }
    
    try {
      _samplingTimer?.cancel();
      _autoRestartTimer?.cancel();
      await _pauseRecordingImpl();
      _updateState(RecordingState.paused);
      DebugLogger.info('✅ SimpleSttRecorder paused successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to pause SimpleSttRecorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> resumeRecording() async {
    DebugLogger.info('▶️ SimpleSttRecorder.resumeRecording called');
    
    if (_state != RecordingState.paused) {
      throw StateError('Cannot resume recording from state: $_state');
    }
    
    try {
      await _resumeRecordingImpl();
      _startSamplingTimer();
      _startAutoRestartTimer();
      _updateState(RecordingState.recording);
      DebugLogger.info('✅ SimpleSttRecorder resumed successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to resume SimpleSttRecorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> stopRecording() async {
    DebugLogger.info('⏹️ SimpleSttRecorder.stopRecording called');
    
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      throw StateError('Cannot stop recording from state: $_state');
    }
    
    try {
      _samplingTimer?.cancel();
      _autoRestartTimer?.cancel();
      await _stopRecordingImpl();
      _updateState(RecordingState.stopped);
      DebugLogger.info('✅ SimpleSttRecorder stopped successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to stop SimpleSttRecorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> dispose() async {
    DebugLogger.info('🗑️ SimpleSttRecorder.dispose called');
    
    try {
      _samplingTimer?.cancel();
      _autoRestartTimer?.cancel();
      _subtitleSubscription?.cancel();
      
      // Dispose all observees
      for (final observee in _observees) {
        await observee.dispose();
      }
      _observees.clear();
      
      await _stateController.close();
      await _disposeImpl();
      DebugLogger.info('✅ SimpleSttRecorder disposed successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to dispose SimpleSttRecorder: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  void publishSignalData(SignalData data) {
    final signalObservees = getObserveesByType(ObserveeDataType.signal);
    for (final observee in signalObservees) {
      try {
        observee.onSignalData(data);
      } catch (e, stackTrace) {
        observee.onError(e, stackTrace);
      }
    }
  }
  
  @override
  void publishTextData(TextData data) {
    final textObservees = getObserveesByType(ObserveeDataType.text);
    for (final observee in textObservees) {
      try {
        observee.onTextData(data);
      } catch (e, stackTrace) {
        observee.onError(e, stackTrace);
      }
    }
  }
  
  @override
  void publishRawAudioData(RawAudioData data) {
    final rawObservees = getObserveesByType(ObserveeDataType.raw);
    for (final observee in rawObservees) {
      try {
        observee.onRawAudioData(data);
      } catch (e, stackTrace) {
        observee.onError(e, stackTrace);
      }
    }
  }
  
  // === Private Implementation Methods ===
  
  Future<void> _startRecordingImpl() async {
    DebugLogger.info('🚀 SimpleSttRecorder._startRecordingImpl called');
    
    // Initialize STT service if needed
    if (!_sttService.isInitialized) {
      DebugLogger.info('Initializing STT service...');
      final initResult = await _sttService.initialize();
      DebugLogger.info('STT initialization result: $initResult');
      
      if (!initResult) {
        throw Exception('Failed to initialize STT service');
      }
    }
    
    // Double-check permission
    final hasPermission = await _sttService.hasPermission();
    DebugLogger.info('🎤 STT Permission check: $hasPermission');
    
    if (!hasPermission) {
      throw Exception('No microphone permission for STT');
    }
    
    // Setup STT callbacks
    DebugLogger.info('Setting up STT callbacks...');
    _setupSTTCallbacks();
    
    // Start STT with subtitle manager
    DebugLogger.info('Starting STT listening...');
    final startResult = await _sttService.startListening(subtitleManager: _subtitleManager);
    DebugLogger.info('STT start listening result: $startResult');
    
    if (!startResult) {
      throw Exception('Failed to start STT listening');
    }
    
    DebugLogger.info('✅ SimpleSttRecorder._startRecordingImpl completed');
  }
  
  Future<void> _pauseRecordingImpl() async {
    DebugLogger.info('⏸️ SimpleSttRecorder._pauseRecordingImpl called');
    await _sttService.stopListening();
    DebugLogger.info('✅ SimpleSttRecorder._pauseRecordingImpl completed');
  }
  
  Future<void> _resumeRecordingImpl() async {
    DebugLogger.info('▶️ SimpleSttRecorder._resumeRecordingImpl called');
    _setupSTTCallbacks();
    await _sttService.startListening(subtitleManager: _subtitleManager);
    DebugLogger.info('✅ SimpleSttRecorder._resumeRecordingImpl completed');
  }
  
  Future<void> _stopRecordingImpl() async {
    DebugLogger.info('⏹️ SimpleSttRecorder._stopRecordingImpl called');
    await _sttService.stopListening();
    _clearSTTCallbacks();
    DebugLogger.info('✅ SimpleSttRecorder._stopRecordingImpl completed');
  }
  
  Future<void> _disposeImpl() async {
    DebugLogger.info('🗑️ SimpleSttRecorder._disposeImpl called');
    _clearSTTCallbacks();
    await _sttService.dispose();
    // Note: SubtitleDisplayManager is now managed by RecordingScreen, don't dispose here
    DebugLogger.info('✅ SimpleSttRecorder._disposeImpl completed');
  }
  
  /// Start sampling timer
  void _startSamplingTimer() {
    _samplingTimer?.cancel();
    _samplingTimer = Timer.periodic(_config.samplingInterval, (timer) {
      if (_state == RecordingState.recording) {
        _performSampling();
      }
    });
  }
  
  /// Start auto-restart timer for continuous STT recognition
  void _startAutoRestartTimer() {
    _autoRestartTimer?.cancel();
    _autoRestartTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Check if we need to restart based on activity detection
      if (_state == RecordingState.recording && _sttService.isInitialized && !_sttService.isListening) {
        _checkForRestartNeed();
      }
    });
  }
  
  /// Intelligent restart decision based on audio activity
  void _checkForRestartNeed() {
    final now = DateTime.now();
    
    // Update activity detection
    _updateActivityDetection();
    
    // Restart immediately if there's recent audio activity
    if (_hasRecentActivity) {
      DebugLogger.info('🎵 Audio activity detected - immediate restart');
      _restartSTTSafely();
      return;
    }
    
    // Pre-warm restart when getting close to timeout (proactive restart)
    if (_lastSTTResult == null || now.difference(_lastSTTResult!).inSeconds > 5) {
      DebugLogger.info('⏰ Pre-warming restart to prevent audio clipping');
      _restartSTTSafely();
      return;
    }
    
    DebugLogger.log('💤 No activity detected, waiting...');
  }
  
  /// Update audio activity detection
  void _updateActivityDetection() {
    final now = DateTime.now();
    
    // Add current audio level to buffer
    _audioLevelBuffer.add(_lastAmplitude);
    
    // Keep only last 3 seconds of data (assuming 30ms sampling)
    const maxBufferSize = 100; // 3 seconds worth
    if (_audioLevelBuffer.length > maxBufferSize) {
      _audioLevelBuffer.removeAt(0);
    }
    
    // Detect significant audio activity (more sensitive to catch speech start)
    if (_audioLevelBuffer.length >= 5) {  // Reduced sample count for faster response
      final recentLevels = _audioLevelBuffer.skip(_audioLevelBuffer.length - 5);
      final avgLevel = recentLevels.reduce((a, b) => a + b) / recentLevels.length;
      final hasSignificantAudio = avgLevel > 0.03; // Ultra-sensitive to catch speech start
      
      _hasRecentActivity = hasSignificantAudio;
      
      if (hasSignificantAudio) {
        DebugLogger.info('🔊 Speech detected - trigger restart: ${avgLevel.toStringAsFixed(3)}');
      }
    }
  }
  
  /// Check if the recorder is still mounted (not disposed)
  bool get mounted => !_stateController.isClosed;
  
  /// Simple STT restart - pauseFor is long enough, so keep it simple
  Future<void> _restartSTTSafely() async {
    final now = DateTime.now();
    
    // Prevent overlapping restart attempts
    if (_isRestartInProgress) {
      DebugLogger.warning('⚠️ Restart already in progress, skipping...');
      return;
    }
    
    // Rate limiting: min 250ms between attempts (aggressive for minimal gaps)
    if (_lastRestartAttempt != null && 
        now.difference(_lastRestartAttempt!).inMilliseconds < 250) {
      DebugLogger.warning('⚠️ Too soon since last restart attempt, waiting...');
      return;
    }
    
    _isRestartInProgress = true;
    _lastRestartAttempt = now;
    
    try {
      DebugLogger.info('🔄 Simple STT restart initiated...');
      
      // Ultra-quick restart to minimize audio clipping
      if (_sttService.isListening) {
        await _sttService.stopListening();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Clear and setup callbacks
      _clearSTTCallbacks();
      _setupSTTCallbacks();
      
      // Restart immediately
      await _sttService.startListening(subtitleManager: _subtitleManager);
      
      DebugLogger.info('✅ STT service restarted successfully');
      
    } catch (e) {
      DebugLogger.error('❌ Failed to restart STT service: $e');
    } finally {
      _isRestartInProgress = false;
    }
  }
  
  
  /// Perform sampling
  void _performSampling() {
    onSamplingTick();
  }
  
  /// Sampling tick - generates signal data
  void onSamplingTick() {
    if (_state == RecordingState.recording) {
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
          'source': 'simple_stt',
          'has_recent_signal': hasRecentSignal,
        },
      );
      
      publishSignalData(signalData);
    }
  }
  
  /// Update state
  void _updateState(RecordingState newState) {
    _state = newState;
    _stateController.add(newState);
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
      
      // DebugLogger.info('🎵 STT Level: $level → Amplitude: ${amplitude.toStringAsFixed(2)}');  // Commented for cleaner logs
    };
    
    // STT results are tracked via SubtitleDisplayManager subscription
    
    // Error callback
    _sttService.onError = (error) {
      DebugLogger.error('🚨 STT Error: $error');
      // Propagate error to all Observees
      for (final observee in _observees) {
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
  
  /// Subscribe to subtitle results to track STT activity
  void _subscribeToSubtitleResults() {
    _subtitleSubscription = _subtitleManager.currentStream.listen(
      (subtitleItem) {
        if (subtitleItem != null && subtitleItem.text.isNotEmpty) {
          _lastSTTResult = DateTime.now();
          DebugLogger.info('📝 STT result received: ${subtitleItem.text}');
          
          // Immediately restart STT after final result to minimize gaps
          if (subtitleItem.isConfirmed && _state == RecordingState.recording) {
            DebugLogger.info('🚀 Final result confirmed - immediate restart for continuous recognition');
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_state == RecordingState.recording && !_sttService.isListening && !_isRestartInProgress) {
                DebugLogger.info('⚡ Final result restart executing...');
                _restartSTTSafely();
              } else {
                DebugLogger.info('⏭️ Final result restart skipped (already in progress or listening)');
              }
            });
          }
        }
      },
      onError: (error) {
        DebugLogger.error('❌ Subtitle stream error: $error');
      },
    );
  }
  
  /// Get the subtitle manager for external access
  SubtitleDisplayManager get subtitleManager => _subtitleManager;
  
  /// Set a new subtitle manager (for external management)
  void setSubtitleManager(SubtitleDisplayManager newManager) {
    // Cancel current subscription
    _subtitleSubscription?.cancel();
    
    // Dispose old manager if it's different
    if (_subtitleManager != newManager) {
      // Don't dispose the old one as it might be managed externally
      DebugLogger.info('🔄 Replacing SubtitleDisplayManager');
    }
    
    // Set new manager
    _subtitleManager = newManager;
    
    // Re-subscribe to new manager
    _subscribeToSubtitleResults();
    
    DebugLogger.info('✅ SubtitleDisplayManager replaced successfully');
  }
}