import 'dart:async';
import '../interfaces/i_audio_recorder.dart';
import '../interfaces/i_observee.dart';
import '../interfaces/audio_data_types.dart';

/// 기본 오디오 녹음기 구현체
/// 다른 구체적인 녹음기들의 베이스 클래스
abstract class BaseAudioRecorder implements IAudioRecorder {
  late AudioRecorderConfig _config;
  final List<IObservee> _observees = [];
  final StreamController<RecordingState> _stateController = StreamController<RecordingState>.broadcast();
  
  RecordingState _state = RecordingState.uninitialized;
  Timer? _samplingTimer;
  
  @override
  RecordingState get state => _state;
  
  @override
  Stream<RecordingState> get stateStream => _stateController.stream;
  
  @override
  AudioRecorderConfig get config => _config;
  
  @override
  List<IObservee> get observees => List.unmodifiable(_observees);
  
  @override
  Future<void> initialize(AudioRecorderConfig config) async {
    _config = config;
    
    // 모든 Observee 초기화
    for (final observee in _observees) {
      await observee.initialize();
    }
    
    _updateState(RecordingState.ready);
  }
  
  @override
  void addObservee(IObservee observee) {
    if (!_observees.contains(observee)) {
      _observees.add(observee);
    }
  }
  
  @override
  void removeObservee(IObservee observee) {
    _observees.remove(observee);
  }
  
  @override
  List<IObservee> getObserveesByType(ObserveeDataType dataType) {
    return _observees
        .where((observee) => observee.supportedDataTypes.contains(dataType))
        .toList();
  }
  
  @override
  Future<void> startRecording() async {
    if (_state != RecordingState.ready && _state != RecordingState.stopped) {
      throw StateError('Cannot start recording from state: $_state');
    }
    
    await _startRecordingImpl();
    _startSamplingTimer();
    _updateState(RecordingState.recording);
  }
  
  @override
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) {
      throw StateError('Cannot pause recording from state: $_state');
    }
    
    _samplingTimer?.cancel();
    await _pauseRecordingImpl();
    _updateState(RecordingState.paused);
  }
  
  @override
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) {
      throw StateError('Cannot resume recording from state: $_state');
    }
    
    await _resumeRecordingImpl();
    _startSamplingTimer();
    _updateState(RecordingState.recording);
  }
  
  @override
  Future<void> stopRecording() async {
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      throw StateError('Cannot stop recording from state: $_state');
    }
    
    _samplingTimer?.cancel();
    await _stopRecordingImpl();
    _updateState(RecordingState.stopped);
  }
  
  @override
  Future<void> dispose() async {
    _samplingTimer?.cancel();
    
    // 모든 Observee 정리
    for (final observee in _observees) {
      await observee.dispose();
    }
    _observees.clear();
    
    await _stateController.close();
    await _disposeImpl();
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
  
  /// 샘플링 타이머 시작
  void _startSamplingTimer() {
    _samplingTimer?.cancel();
    _samplingTimer = Timer.periodic(_config.samplingInterval, (timer) {
      if (_state == RecordingState.recording) {
        _performSampling();
      }
    });
  }
  
  /// 샘플링 수행 (하위 클래스에서 구현)
  void _performSampling() {
    onSamplingTick();
  }
  
  /// 상태 업데이트
  void _updateState(RecordingState newState) {
    _state = newState;
    _stateController.add(newState);
  }
  
  // 하위 클래스에서 구현해야 하는 추상 메서드들
  Future<void> _startRecordingImpl() async {
    throw UnimplementedError('_startRecordingImpl must be implemented by subclass');
  }
  
  Future<void> _pauseRecordingImpl() async {
    throw UnimplementedError('_pauseRecordingImpl must be implemented by subclass');
  }
  
  Future<void> _resumeRecordingImpl() async {
    throw UnimplementedError('_resumeRecordingImpl must be implemented by subclass');
  }
  
  Future<void> _stopRecordingImpl() async {
    throw UnimplementedError('_stopRecordingImpl must be implemented by subclass');
  }
  
  Future<void> _disposeImpl() async {
    throw UnimplementedError('_disposeImpl must be implemented by subclass');
  }
  
  /// 샘플링 틱 - 하위 클래스에서 오버라이드
  void onSamplingTick() {
    // 기본 구현: 아무것도 하지 않음
  }
}