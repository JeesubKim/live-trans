import 'dart:async';
import '../../../services/audio_recorder_service.dart';
import '../../../utils/debug_logger.dart';
import '../interfaces/audio_data_types.dart';
import 'base_audio_recorder.dart';

/// 직접 오디오 녹음기
/// AudioRecorderService를 래핑하여 원시 오디오 데이터를 수집
class DirectAudioRecorder extends BaseAudioRecorder {
  final AudioRecorderService _recorderService;
  
  StreamSubscription<double>? _audioLevelSubscription;
  
  DirectAudioRecorder(this._recorderService);
  
  @override
  Future<bool> hasPermission() async {
    return await _recorderService.hasPermission();
  }
  
  @override
  Future<bool> requestPermission() async {
    return await _recorderService.requestPermission();
  }
  
  @override
  Future<void> _startRecordingImpl() async {
    try {
      // 스트림 구독 설정
      _setupAudioStreams();
      
      // 녹음 시작
      final success = await _recorderService.startRecording();
      if (!success) {
        throw Exception('Failed to start audio recorder service');
      }
      
      DebugLogger.info('Direct Audio Recorder started');
    } catch (e) {
      DebugLogger.error('Failed to start Direct Audio Recorder: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> _pauseRecordingImpl() async {
    await _recorderService.pauseRecording();
    DebugLogger.info('Direct Audio Recorder paused');
  }
  
  @override
  Future<void> _resumeRecordingImpl() async {
    await _recorderService.resumeRecording();
    DebugLogger.info('Direct Audio Recorder resumed');
  }
  
  @override
  Future<void> _stopRecordingImpl() async {
    _clearAudioStreams();
    await _recorderService.stopRecording();
    DebugLogger.info('Direct Audio Recorder stopped');
  }
  
  @override
  Future<void> _disposeImpl() async {
    _clearAudioStreams();
    await _recorderService.dispose();
    DebugLogger.info('Direct Audio Recorder disposed');
  }
  
  /// 오디오 스트림 구독 설정
  void _setupAudioStreams() {
    // 오디오 레벨 스트림 구독
    final amplitudeStream = _recorderService.amplitudeStream;
    if (amplitudeStream != null) {
      _audioLevelSubscription = amplitudeStream.listen(
        (level) {
          // 오디오 레벨을 Signal 데이터로 변환
          final signalData = SignalData(
            amplitude: level,
            timestamp: DateTime.now(),
            metadata: {
              'source': 'direct_audio',
              'raw_level': level,
            },
          );
          
          publishSignalData(signalData);
        },
        onError: (error) {
          DebugLogger.error('Audio level stream error: $error');
          for (final observee in observees) {
            observee.onError(error, StackTrace.current);
          }
        },
      );
    }
  }
  
  /// 오디오 스트림 구독 해제
  void _clearAudioStreams() {
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;
  }
}