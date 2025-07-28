# Software Architecture - Subtitify Real-time STT App

## Overview
Subtitify는 실시간 음성 인식을 통한 자막 생성 애플리케이션으로, 연속적인 음성 입력을 끊김 없이 처리하여 실시간 텍스트로 변환하는 시스템입니다.

## Architecture Patterns

### 1. Observer Pattern (관찰자 패턴)
실시간 데이터 스트림 처리를 위한 핵심 패턴

```
[STT Service] --notify--> [SubtitleDisplayManager] --stream--> [UI Components]
```

#### 구현:
- **Publisher**: `SpeechToTextService` - STT 결과 발행
- **Manager**: `SubtitleDisplayManager` - 상태 관리 및 스트림 중계
- **Subscribers**: Flutter UI Widgets - 실시간 업데이트 수신

### 2. Chain of Responsibility Pattern (책임 연쇄 패턴)
오디오 데이터 처리 파이프라인

```
[Audio Input] -> [Recorder] -> [Processor] -> [Visualizer] -> [Observer]
```

#### 구현:
- **AudioPipeline**: 전체 처리 체인 관리
- **SimpleSttRecorder**: 오디오 입력 및 STT 처리
- **WaveformVisualizer**: 시각화 데이터 생성
- **AmplifierObservee**: 신호 증폭 및 관찰

### 3. Factory Pattern (팩토리 패턴)
다양한 STT 엔진 지원을 위한 추상화

```dart
class AudioPipelineFactory {
  static Future<AudioPipeline> createSTTPipeline() async {
    final sttService = SpeechToTextService();
    final recorder = SimpleSttRecorder(sttService);
    // ...
  }
}
```

## Core Interfaces

### 1. IAudioRecorder Interface
```dart
abstract class IAudioRecorder {
  RecordingState get state;
  Stream<RecordingState> get stateStream;
  
  Future<void> initialize(AudioRecorderConfig config);
  Future<void> startRecording();
  Future<void> pauseRecording();
  Future<void> stopRecording();
  Future<void> dispose();
  
  // Observer pattern support
  void addObservee(IObservee observee);
  void removeObservee(IObservee observee);
}
```

### 2. IObservee Interface
```dart
abstract class IObservee {
  String get id;
  List<ObserveeDataType> get supportedDataTypes;
  
  Future<void> initialize();
  void onSignalData(SignalData data);
  void onTextData(TextData data);
  void onRawAudioData(RawAudioData data);
  void onError(dynamic error, StackTrace stackTrace);
  Future<void> dispose();
}
```

### 3. Data Types
```dart
enum ObserveeDataType { signal, text, raw }

class SignalData {
  final double amplitude;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
}

class TextData {
  final String text;
  final double confidence;
  final bool isFinal;
  final DateTime timestamp;
}
```

## Component Architecture

### 1. Service Layer
```
SpeechToTextService (Singleton)
├── Android STT Engine Integration
├── Locale Management
├── Session Management
└── Error Handling

SubtitleDisplayManager
├── Stream Controllers (History, Current, Realtime)
├── State Management
├── Memory Management (LRU Cache)
└── Export Functions
```

### 2. Core Audio Pipeline
```
AudioPipeline
├── SimpleSttRecorder (IAudioRecorder)
│   ├── STT Service Integration  
│   ├── Activity Detection
│   ├── Auto-restart Logic
│   └── Observer Management
├── WaveformVisualizer (IProcessor)
│   ├── Signal Processing
│   ├── Amplitude Calculation
│   └── Visual Data Generation
└── AmplifierObservee (IObservee)
    ├── Signal Amplification
    ├── Data Publishing
    └── Error Handling
```

### 3. UI Layer
```
RecordingScreen (StatefulWidget)
├── Audio Pipeline Management
├── Subtitle Stream Subscriptions
├── Real-time Display Logic
├── Control Interface
└── Settings Integration

Components:
├── AudioWaveformComponent
├── SubtitifyingComponent  
└── SelectComponent
```

## Data Flow Architecture

### 1. Audio Processing Flow
```
[Microphone] 
    ↓ (Android Audio System)
[SpeechToTextService] 
    ↓ (Partial/Final Results)
[SubtitleDisplayManager]
    ↓ (Stream Events)
[UI Components]
    ↓ (Visual Update)
[User Display]
```

### 2. State Management Flow
```
[User Input] → [UI State] → [Service Calls] → [Stream Updates] → [UI Rebuild]
                    ↑                                          ↓
            [Settings Service] ←←←←←←←←←←←←←←←←←←←←←←←← [State Persistence]
```

### 3. Memory Management
```
SubtitleDisplayManager:
├── _history: List<SubtitleItem> (max 20 items)
├── _currentItem: SubtitleItem? (single item)
├── _realtimeText: String (current input)
└── Stream Controllers (auto-cleanup)

Audio Pipeline:
├── _audioLevelBuffer: List<double> (max 100 samples)
├── _waveformData: List<double> (max 50 bars)
└── Timer Management (auto-cancel)
```

## Design Principles

### 1. Single Responsibility Principle
- **SpeechToTextService**: STT 엔진 관리만 담당
- **SubtitleDisplayManager**: 자막 상태 관리만 담당
- **SimpleSttRecorder**: 오디오 녹음 및 STT 통합만 담당

### 2. Open/Closed Principle
- **IObservee** 인터페이스를 통한 확장 가능한 관찰자
- **Factory Pattern**을 통한 새로운 STT 엔진 추가 지원

### 3. Dependency Inversion Principle
- 구체적인 구현이 아닌 인터페이스에 의존
- **AudioPipeline**이 **IAudioRecorder** 인터페이스에 의존

### 4. Asynchronous Architecture
- 모든 I/O 작업 비동기 처리
- **Future.microtask()** 활용한 논블로킹 설계
- Stream 기반 반응형 프로그래밍

## Error Handling Strategy

### 1. Graceful Degradation
```dart
// STT 실패 시에도 앱 동작 유지
if (!sttResult) {
  DebugLogger.warning('STT failed, continuing with fallback');
  return false; // 앱 종료하지 않음
}
```

### 2. Circuit Breaker Pattern
```dart
// 연속 실패 시 자동 복구 시도
if (_consecutiveFailures > 3) {
  await _performFullRestart();
}
```

### 3. Resource Cleanup
```dart
// 모든 리소스의 명시적 해제
@override
void dispose() {
  _timer?.cancel();
  _streamController.close();
  super.dispose();
}
```

## Performance Optimizations

### 1. Memory Optimization
- **LRU Cache**: 최대 20개 자막 아이템 유지
- **Stream Buffer**: 100개 오디오 샘플 유지  
- **Auto-cleanup**: 사용하지 않는 리소스 자동 해제

### 2. CPU Optimization
- **Microtask Scheduling**: UI 블로킹 방지
- **Timer-based Sampling**: 효율적인 주기적 작업
- **Lazy Initialization**: 필요시에만 리소스 할당

### 3. Battery Optimization
- **Intelligent Restart**: 음성 활동 감지 기반 재시작
- **Reduced Polling**: 800ms 간격으로 상태 체크
- **Power-aware Design**: 불필요한 연산 최소화

## Security Considerations

### 1. Privacy Protection
- **Offline Processing**: Android 기본 STT 엔진 사용
- **No Network**: 음성 데이터 외부 전송 없음
- **Local Storage**: 모든 데이터 로컬 저장

### 2. Permission Management
- **Runtime Permissions**: 마이크 권한 동적 요청
- **Graceful Fallback**: 권한 거부 시 적절한 처리

### 3. Data Integrity
- **Input Validation**: 모든 사용자 입력 검증
- **Error Boundaries**: 예외 발생 시 앱 보호

## Scalability Design

### 1. Modular Architecture
- 각 컴포넌트의 독립적 확장 가능
- 새로운 STT 엔진 쉽게 추가 가능

### 2. Plugin Architecture
- **IObservee** 인터페이스를 통한 플러그인 지원
- 런타임 컴포넌트 등록/해제

### 3. Configuration Management
- **Settings Service**: 중앙화된 설정 관리
- **Runtime Configuration**: 앱 재시작 없이 설정 변경

## Testing Strategy

### 1. Unit Testing
- Service 클래스의 개별 메서드 테스트
- Mock 객체를 활용한 의존성 격리

### 2. Integration Testing
- 전체 오디오 파이프라인 테스트
- STT 서비스와 UI 통합 테스트

### 3. Performance Testing
- 메모리 사용량 모니터링
- CPU 사용률 측정
- 배터리 소모 분석

---

## Conclusion

Subtitify의 아키텍처는 **실시간 성능**, **안정성**, **확장성**을 모두 고려하여 설계되었습니다. Observer 패턴과 Chain of Responsibility 패턴을 통해 반응형이면서도 유지보수가 용이한 구조를 구현했으며, 비동기 처리와 리소스 관리를 통해 최적의 사용자 경험을 제공합니다.