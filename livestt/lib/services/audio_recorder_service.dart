import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/debug_logger.dart';

class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._internal();
  factory AudioRecorderService() => _instance;
  AudioRecorderService._internal();

  final Record _recorder = Record();
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;
  
  // Amplitude stream for real-time monitoring
  StreamController<double>? _amplitudeController;
  Timer? _amplitudeTimer;

  bool get isRecording => _isRecording;
  
  // Stream for real-time audio data
  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  
  // Stream for amplitude data
  Stream<double>? get amplitudeStream => _amplitudeController?.stream;

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  // Check if permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }

  // Start recording
  Future<bool> startRecording() async {
    try {
      // Check permission
      if (!await hasPermission()) {
        DebugLogger.warning('Microphone permission not granted');
        if (!await requestPermission()) {
          return false;
        }
      }

      // Check if already recording
      if (_isRecording) {
        DebugLogger.log('Already recording');
        return false;
      }

      // Close existing controllers if they exist
      await _audioStreamController?.close();
      await _amplitudeController?.close();
      _audioStreamController = null;
      _amplitudeController = null;
      
      // Create new stream controllers
      _audioStreamController = StreamController<Uint8List>.broadcast();
      _amplitudeController = StreamController<double>.broadcast();
      
      // Start amplitude monitoring
      _startAmplitudeMonitoring();

      // Start recording to file (null path = app's internal storage)
      await _recorder.start(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        samplingRate: 16000,
      );

      _isRecording = true;
      DebugLogger.info('Recording started successfully');
      DebugLogger.log('Recorder is recording: ${await _recorder.isRecording()}'); // 상태 확인
      return true;
    } catch (e) {
      DebugLogger.error('Error starting recording: $e');
      
      // Reset state on error
      _isRecording = false;
      
      // Clean up controllers on error
      await _audioStreamController?.close();
      await _amplitudeController?.close();
      _audioStreamController = null;
      _amplitudeController = null;
      _amplitudeTimer?.cancel();
      
      return false;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        DebugLogger.log('Not currently recording');
        return null;
      }

      // Stop the recording and get the file path
      final path = await _recorder.stop();
      
      _isRecording = false;
      
      // Close the stream controller
      await _audioStreamController?.close();
      _audioStreamController = null;

      DebugLogger.info('Recording stopped. File saved at: $path');
      return path;
    } catch (e) {
      DebugLogger.error('Error stopping recording: $e');
      return null;
    }
  }

  // Pause recording
  Future<void> pauseRecording() async {
    try {
      if (_isRecording) {
        await _recorder.pause();
        DebugLogger.info('Recording paused');
      }
    } catch (e) {
      DebugLogger.error('Error pausing recording: $e');
    }
  }

  // Resume recording
  Future<void> resumeRecording() async {
    try {
      if (_isRecording) {
        await _recorder.resume();
        DebugLogger.info('Recording resumed');
      }
    } catch (e) {
      DebugLogger.error('Error resuming recording: $e');
    }
  }

  // Get current amplitude (volume level)
  Future<double> getAmplitude() async {
    try {
      if (_isRecording) {
        final amplitude = await _recorder.getAmplitude();
        return amplitude.current;
      }
      return 0.0;
    } catch (e) {
      DebugLogger.error('Error getting amplitude: $e');
      return 0.0;
    }
  }

  // Start amplitude monitoring
  void _startAmplitudeMonitoring() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      try {
        final amplitude = await getAmplitude();
        _amplitudeController?.add(amplitude);
      } catch (e) {
        DebugLogger.error('Error getting amplitude: $e');
      }
    });
  }

  // Dispose resources
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      _amplitudeTimer?.cancel();
      await _audioStreamController?.close();
      await _amplitudeController?.close();
      _audioStreamController = null;
      _amplitudeController = null;
      _recorder.dispose();
    } catch (e) {
      DebugLogger.error('Error disposing audio recorder: $e');
    }
  }
}