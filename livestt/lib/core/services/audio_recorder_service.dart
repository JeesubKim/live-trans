import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../models/settings.dart';

/// Abstract interface for audio recording services
abstract class AudioRecorderService {
  /// Stream of audio levels for waveform visualization
  Stream<double> get audioLevelStream;
  
  /// Stream of recording status updates
  Stream<RecorderStatus> get statusStream;
  
  /// Current recording status
  RecorderStatus get status;
  
  /// Duration of current recording
  Duration get recordingDuration;
  
  /// Whether recording is currently active
  bool get isRecording;
  
  /// Whether recording is paused
  bool get isPaused;

  /// Initialize the recorder with given settings
  Future<void> initialize(RecordingSettings settings);
  
  /// Start recording to a file
  Future<void> startRecording(String filePath);
  
  /// Stop recording and finalize the file
  Future<String?> stopRecording();
  
  /// Pause recording (can be resumed)
  Future<void> pauseRecording();
  
  /// Resume recording after pause
  Future<void> resumeRecording();
  
  /// Update recording settings
  Future<void> updateSettings(RecordingSettings settings);
  
  /// Check if microphone permission is granted
  Future<bool> hasPermission();
  
  /// Request microphone permission
  Future<bool> requestPermission();
  
  /// Clean up resources
  Future<void> dispose();
}

/// Status of the audio recorder
enum RecorderStatus {
  uninitialized,
  initializing,
  ready,
  recording,
  paused,
  stopped,
  error,
  disposed,
}

/// Exception thrown by audio recorder
class RecorderException implements Exception {
  final String message;
  final RecorderErrorType type;
  final dynamic originalError;

  RecorderException(this.message, this.type, [this.originalError]);

  @override
  String toString() => 'RecorderException: $message (${type.name})';
}

enum RecorderErrorType {
  permissionDenied,
  microphoneNotAvailable,
  fileSystemError,
  initializationFailed,
  recordingFailed,
  invalidFormat,
  unknown,
}

/// Default implementation of AudioRecorderService
class DefaultAudioRecorderService implements AudioRecorderService {
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  final StreamController<RecorderStatus> _statusController = StreamController<RecorderStatus>.broadcast();
  
  RecorderStatus _status = RecorderStatus.uninitialized;
  RecordingSettings? _settings;
  Timer? _recordingTimer;
  Timer? _audioLevelTimer;
  DateTime? _recordingStartTime;
  DateTime? _pauseStartTime;
  Duration _pausedDuration = Duration.zero;
  String? _currentFilePath;
  
  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  @override
  Stream<RecorderStatus> get statusStream => _statusController.stream;
  
  @override
  RecorderStatus get status => _status;
  
  @override
  Duration get recordingDuration {
    if (_recordingStartTime == null) return Duration.zero;
    
    final now = DateTime.now();
    final elapsed = now.difference(_recordingStartTime!);
    
    // Subtract paused time
    Duration totalPausedTime = _pausedDuration;
    if (_status == RecorderStatus.paused && _pauseStartTime != null) {
      totalPausedTime += now.difference(_pauseStartTime!);
    }
    
    return elapsed - totalPausedTime;
  }
  
  @override
  bool get isRecording => _status == RecorderStatus.recording;
  
  @override
  bool get isPaused => _status == RecorderStatus.paused;

  @override
  Future<void> initialize(RecordingSettings settings) async {
    _updateStatus(RecorderStatus.initializing);
    _settings = settings;
    
    try {
      // Check permissions
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        throw RecorderException('Microphone permission denied', RecorderErrorType.permissionDenied);
      }
      
      // TODO: Initialize actual audio recorder
      // For now, simulate initialization
      await Future.delayed(const Duration(milliseconds: 300));
      
      _updateStatus(RecorderStatus.ready);
    } catch (e) {
      _updateStatus(RecorderStatus.error);
      throw RecorderException('Failed to initialize audio recorder', RecorderErrorType.initializationFailed, e);
    }
  }

  @override
  Future<void> startRecording(String filePath) async {
    if (_status != RecorderStatus.ready && _status != RecorderStatus.stopped) {
      throw RecorderException('Recorder not ready', RecorderErrorType.recordingFailed);
    }
    
    _currentFilePath = filePath;
    _recordingStartTime = DateTime.now();
    _pausedDuration = Duration.zero;
    _pauseStartTime = null;
    
    try {
      // TODO: Start actual audio recording
      // For now, simulate recording
      _updateStatus(RecorderStatus.recording);
      _startAudioLevelSimulation();
      
    } catch (e) {
      _updateStatus(RecorderStatus.error);
      throw RecorderException('Failed to start recording', RecorderErrorType.recordingFailed, e);
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (_status != RecorderStatus.recording && _status != RecorderStatus.paused) {
      return null;
    }
    
    try {
      // TODO: Stop actual audio recording and finalize file
      _audioLevelTimer?.cancel();
      _recordingTimer?.cancel();
      
      _updateStatus(RecorderStatus.stopped);
      
      final filePath = _currentFilePath;
      _currentFilePath = null;
      _recordingStartTime = null;
      _pausedDuration = Duration.zero;
      _pauseStartTime = null;
      
      return filePath;
      
    } catch (e) {
      _updateStatus(RecorderStatus.error);
      throw RecorderException('Failed to stop recording', RecorderErrorType.recordingFailed, e);
    }
  }

  @override
  Future<void> pauseRecording() async {
    if (_status != RecorderStatus.recording) return;
    
    _pauseStartTime = DateTime.now();
    _audioLevelTimer?.cancel();
    
    // TODO: Pause actual audio recording
    _updateStatus(RecorderStatus.paused);
  }

  @override
  Future<void> resumeRecording() async {
    if (_status != RecorderStatus.paused) return;
    
    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }
    
    // TODO: Resume actual audio recording
    _updateStatus(RecorderStatus.recording);
    _startAudioLevelSimulation();
  }

  @override
  Future<void> updateSettings(RecordingSettings settings) async {
    _settings = settings;
    // TODO: Apply new settings to running recorder
  }

  @override
  Future<bool> hasPermission() async {
    // TODO: Check actual microphone permission
    // For now, simulate permission check
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    // TODO: Request actual microphone permission
    // For now, simulate permission request
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<void> dispose() async {
    _audioLevelTimer?.cancel();
    _recordingTimer?.cancel();
    
    _updateStatus(RecorderStatus.disposed);
    
    await _audioLevelController.close();
    await _statusController.close();
  }

  void _updateStatus(RecorderStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _startAudioLevelSimulation() {
    _audioLevelTimer?.cancel();
    
    // Simulate audio levels for waveform visualization
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_status != RecorderStatus.recording) {
        timer.cancel();
        return;
      }
      
      // Generate realistic audio level simulation
      final random = math.Random();
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final level = (math.sin(time * 2) * 0.3 + 0.7) * // Base wave
                   (0.7 + math.sin(time * 0.5) * 0.3) * // Slow modulation
                   (0.8 + random.nextDouble() * 0.4); // Random variation
      
      _audioLevelController.add(level.clamp(0.0, 1.0));
    });
  }
}