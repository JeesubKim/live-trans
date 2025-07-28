import 'audio_data_types.dart';

/// 오디오 데이터를 처리하는 Observer 인터페이스
abstract class IObservee {
  /// 이 Observee가 처리하는 데이터 타입
  Set<ObserveeDataType> get supportedDataTypes;
  
  /// Observee의 고유 식별자
  String get id;
  
  /// 신호세기 데이터 처리
  void onSignalData(SignalData data) {
    // 기본 구현: 아무것도 하지 않음
    // 필요한 경우 override
  }
  
  /// STT 텍스트 데이터 처리
  void onTextData(TextData data) {
    // 기본 구현: 아무것도 하지 않음
    // 필요한 경우 override
  }
  
  /// 원시 오디오 데이터 처리
  void onRawAudioData(RawAudioData data) {
    // 기본 구현: 아무것도 하지 않음
    // 필요한 경우 override
  }
  
  /// Observee 초기화
  Future<void> initialize() async {
    // 기본 구현: 아무것도 하지 않음
  }
  
  /// Observee 정리
  Future<void> dispose() async {
    // 기본 구현: 아무것도 하지 않음
  }
  
  /// 에러 처리
  void onError(Object error, StackTrace stackTrace) {
    // 기본 구현: 아무것도 하지 않음
    // 로깅이나 에러 리포팅을 여기서 할 수 있음
  }
}