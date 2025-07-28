import 'dart:typed_data';

/// 오디오 처리 파이프라인에서 사용되는 데이터 타입들
enum ObserveeDataType {
  signal,    // 신호세기 데이터 (amplitude)
  text,      // STT 변환된 텍스트
  raw,       // 원시 오디오 데이터
}

/// 신호세기 데이터 클래스
class SignalData {
  final double amplitude;    // 신호 세기 (dB 또는 normalized value)
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const SignalData({
    required this.amplitude,
    required this.timestamp,
    this.metadata,
  });

  @override
  String toString() => 'SignalData(amplitude: $amplitude, timestamp: $timestamp)';
}

/// STT 텍스트 데이터 클래스
class TextData {
  final String text;
  final DateTime timestamp;
  final double confidence;   // STT 신뢰도 (0.0 ~ 1.0)
  final bool isFinal;       // 최종 결과인지 여부
  final Map<String, dynamic>? metadata;

  const TextData({
    required this.text,
    required this.timestamp,
    this.confidence = 1.0,
    this.isFinal = true,
    this.metadata,
  });

  @override
  String toString() => 'TextData(text: "$text", confidence: $confidence, isFinal: $isFinal)';
}

/// 원시 오디오 데이터 클래스
class RawAudioData {
  final Uint8List data;
  final DateTime timestamp;
  final int sampleRate;
  final int channels;
  final Map<String, dynamic>? metadata;

  const RawAudioData({
    required this.data,
    required this.timestamp,
    this.sampleRate = 16000,
    this.channels = 1,
    this.metadata,
  });

  @override
  String toString() => 'RawAudioData(size: ${data.length}, sampleRate: $sampleRate, channels: $channels)';
}