import 'dart:async';
import '../interfaces/i_observee.dart';
import '../interfaces/audio_data_types.dart';
import '../../../utils/debug_logger.dart';

/// 오디오 신호 증폭 설정
class AmplifierConfig {
  final double amplificationFactor;  // 증폭 배수
  final double minThreshold;        // 최소 임계값
  final double maxThreshold;        // 최대 임계값
  final double quietBaseline;       // 조용한 상태 기준값
  
  const AmplifierConfig({
    this.amplificationFactor = 3.0,
    this.minThreshold = 0.02,
    this.maxThreshold = 1.0,
    this.quietBaseline = 0.005,
  });
}

/// 오디오 신호 증폭기
/// Signal 타입 데이터를 받아서 증폭된 Signal 데이터를 다음 단계로 전달
class Amplifier implements IObservee {
  final AmplifierConfig _config;
  final List<IObservee> _nextProcessors = [];
  
  @override
  String get id => 'amplifier';
  
  @override
  Set<ObserveeDataType> get supportedDataTypes => {ObserveeDataType.signal};
  
  Amplifier(this._config);
  
  /// 다음 단계 프로세서 추가 (Chain of Responsibility)
  void addNextProcessor(IObservee processor) {
    if (!_nextProcessors.contains(processor)) {
      _nextProcessors.add(processor);
    }
  }
  
  /// 다음 단계 프로세서 제거
  void removeNextProcessor(IObservee processor) {
    _nextProcessors.remove(processor);
  }
  
  @override
  void onSignalData(SignalData data) {
    try {
      // 증폭 로직
      final amplifiedData = _amplifySignal(data);
      
      // 다음 단계 프로세서들에게 전달
      for (final processor in _nextProcessors) {
        if (processor.supportedDataTypes.contains(ObserveeDataType.signal)) {
          processor.onSignalData(amplifiedData);
        }
      }
    } catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }
  
  /// 신호 증폭 로직
  SignalData _amplifySignal(SignalData original) {
    double amplitude = original.amplitude;
    
    // 매우 조용한 경우 기준값 적용
    if (amplitude <= _config.quietBaseline) {
      amplitude = _config.quietBaseline;
    } else {
      // 증폭 적용
      amplitude = amplitude * _config.amplificationFactor;
    }
    
    // 임계값 적용
    amplitude = amplitude.clamp(_config.minThreshold, _config.maxThreshold);
    
    return SignalData(
      amplitude: amplitude,
      timestamp: original.timestamp,
      metadata: {
        ...?original.metadata,
        'amplified': true,
        'original_amplitude': original.amplitude,
        'amplification_factor': _config.amplificationFactor,
      },
    );
  }
  
  @override
  Future<void> initialize() async {
    // 초기화 로직 (필요한 경우)
  }
  
  @override
  Future<void> dispose() async {
    _nextProcessors.clear();
  }
  
  @override
  void onTextData(TextData data) {
    // Amplifier는 텍스트 데이터를 처리하지 않음 - 다음 프로세서로 전달
    for (final processor in _nextProcessors) {
      if (processor.supportedDataTypes.contains(ObserveeDataType.text)) {
        processor.onTextData(data);
      }
    }
  }
  
  @override
  void onRawAudioData(RawAudioData data) {
    // Amplifier는 원시 오디오 데이터를 처리하지 않음 - 다음 프로세서로 전달
    for (final processor in _nextProcessors) {
      if (processor.supportedDataTypes.contains(ObserveeDataType.raw)) {
        processor.onRawAudioData(data);
      }
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    // 에러 로깅 또는 처리
    DebugLogger.error('Amplifier Error: $error');
    DebugLogger.error('Stack Trace: $stackTrace');
  }
}