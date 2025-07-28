import 'dart:async';
import '../interfaces/i_observee.dart';
import '../interfaces/audio_data_types.dart';
import '../../../utils/debug_logger.dart';

/// 파형 시각화 설정
class WaveformVisualizerConfig {
  final int maxBars;              // 최대 바 개수
  final Duration dataRetention;   // 데이터 보관 시간
  final bool enableSmoothing;     // 스무딩 활성화
  final double smoothingFactor;   // 스무딩 계수 (0.0 ~ 1.0)
  
  const WaveformVisualizerConfig({
    this.maxBars = 50,
    this.dataRetention = const Duration(seconds: 30),
    this.enableSmoothing = true,
    this.smoothingFactor = 0.3,
  });
}

/// 파형 시각화 데이터
class WaveformData {
  final List<double> amplitudes;
  final DateTime lastUpdate;
  final int maxBars;
  
  const WaveformData({
    required this.amplitudes,
    required this.lastUpdate,
    required this.maxBars,
  });
  
  WaveformData copyWith({
    List<double>? amplitudes,
    DateTime? lastUpdate,
    int? maxBars,
  }) {
    return WaveformData(
      amplitudes: amplitudes ?? this.amplitudes,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      maxBars: maxBars ?? this.maxBars,
    );
  }
}

/// 파형 시각화 프로세서
/// Signal 데이터를 받아서 UI에서 사용할 수 있는 파형 데이터로 변환
class WaveformVisualizer implements IObservee {
  final WaveformVisualizerConfig _config;
  final List<double> _waveformData = [];
  final StreamController<WaveformData> _waveformController = StreamController<WaveformData>.broadcast();
  
  double _lastSmoothedValue = 0.0;
  
  @override
  String get id => 'waveform_visualizer';
  
  @override
  Set<ObserveeDataType> get supportedDataTypes => {ObserveeDataType.signal};
  
  /// 파형 데이터 스트림
  Stream<WaveformData> get waveformStream => _waveformController.stream;
  
  /// 현재 파형 데이터
  List<double> get currentWaveformData => List.unmodifiable(_waveformData);
  
  WaveformVisualizer(this._config);
  
  @override
  void onSignalData(SignalData data) {
    try {
      double amplitude = data.amplitude;
      
      // 스무딩 적용
      if (_config.enableSmoothing && _waveformData.isNotEmpty) {
        amplitude = _applySmoothingFilter(amplitude);
      }
      
      // 파형 데이터에 추가
      _waveformData.add(amplitude);
      
      // 최대 바 개수 유지 (오래된 데이터 제거)
      if (_waveformData.length > _config.maxBars) {
        _waveformData.removeAt(0);
      }
      
      // 스트림으로 업데이트된 데이터 전송
      final waveformData = WaveformData(
        amplitudes: List.from(_waveformData),
        lastUpdate: data.timestamp,
        maxBars: _config.maxBars,
      );
      
      if (!_waveformController.isClosed) {
        _waveformController.add(waveformData);
      }
      
    } catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }
  
  /// 스무딩 필터 적용
  double _applySmoothingFilter(double newValue) {
    // 지수 이동 평균 (Exponential Moving Average) 사용
    _lastSmoothedValue = (_config.smoothingFactor * newValue) + 
                        ((1.0 - _config.smoothingFactor) * _lastSmoothedValue);
    return _lastSmoothedValue;
  }
  
  /// 파형 데이터 초기화
  void clearWaveformData() {
    _waveformData.clear();
    _lastSmoothedValue = 0.0;
    
    final emptyData = WaveformData(
      amplitudes: [],
      lastUpdate: DateTime.now(),
      maxBars: _config.maxBars,
    );
    
    if (!_waveformController.isClosed) {
      _waveformController.add(emptyData);
    }
  }
  
  /// 특정 개수만큼 빈 데이터 추가 (녹음 시작 시 사용)
  void initializeWithEmptyBars(int count) {
    _waveformData.clear();
    _waveformData.addAll(List.filled(count.clamp(0, _config.maxBars), 0.005));
    
    final initialData = WaveformData(
      amplitudes: List.from(_waveformData),
      lastUpdate: DateTime.now(),
      maxBars: _config.maxBars,
    );
    
    if (!_waveformController.isClosed) {
      _waveformController.add(initialData);
    }
  }
  
  @override
  Future<void> initialize() async {
    clearWaveformData();
  }
  
  @override
  Future<void> dispose() async {
    _waveformData.clear();
    await _waveformController.close();
  }
  
  @override
  void onTextData(TextData data) {
    // WaveformVisualizer는 텍스트 데이터를 처리하지 않음
  }
  
  @override
  void onRawAudioData(RawAudioData data) {
    // WaveformVisualizer는 원시 오디오 데이터를 처리하지 않음
    // 필요하다면 향후 원시 오디오에서 파형 생성 기능 추가 가능
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    DebugLogger.error('WaveformVisualizer Error: $error');
    DebugLogger.error('Stack Trace: $stackTrace');
  }
}