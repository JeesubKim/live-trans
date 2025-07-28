import 'dart:async';
import 'i_observee.dart';
import 'audio_data_types.dart';

/// 오디오 녹음 설정
class AudioRecorderConfig {
  final int sampleRate;
  final int channels;
  final Duration samplingInterval;  // 데이터를 Observee들에게 보내는 간격
  final Map<String, dynamic>? customSettings;

  const AudioRecorderConfig({
    this.sampleRate = 16000,
    this.channels = 1,
    this.samplingInterval = const Duration(milliseconds: 100),
    this.customSettings,
  });
}

/// 녹음 상태
enum RecordingState {
  uninitialized,
  ready,
  recording,
  paused,
  stopped,
  error,
}

/// 오디오 녹음기 인터페이스
abstract class IAudioRecorder {
  /// 현재 녹음 상태
  RecordingState get state;
  
  /// 상태 변경 스트림
  Stream<RecordingState> get stateStream;
  
  /// 현재 설정
  AudioRecorderConfig get config;
  
  /// 등록된 Observee 목록
  List<IObservee> get observees;
  
  /// 초기화
  Future<void> initialize(AudioRecorderConfig config);
  
  /// Observee 추가
  void addObservee(IObservee observee);
  
  /// Observee 제거
  void removeObservee(IObservee observee);
  
  /// 특정 타입의 Observee들 가져오기
  List<IObservee> getObserveesByType(ObserveeDataType dataType);
  
  /// 녹음 시작
  Future<void> startRecording();
  
  /// 녹음 일시정지
  Future<void> pauseRecording();
  
  /// 녹음 재개
  Future<void> resumeRecording();
  
  /// 녹음 중지
  Future<void> stopRecording();
  
  /// 권한 확인
  Future<bool> hasPermission();
  
  /// 권한 요청
  Future<bool> requestPermission();
  
  /// 리소스 정리
  Future<void> dispose();
  
  /// 수동으로 데이터 전송 (테스트용)
  void publishSignalData(SignalData data);
  void publishTextData(TextData data);
  void publishRawAudioData(RawAudioData data);
}