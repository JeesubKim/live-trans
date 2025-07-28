import '../../services/speech_to_text_service.dart';
import '../../services/audio_recorder_service.dart';
import 'interfaces/i_audio_recorder.dart';
import 'interfaces/audio_data_types.dart';
import 'recorders/simple_stt_recorder.dart';
import 'recorders/direct_audio_recorder.dart';
import 'processors/amplifier.dart';
import 'processors/waveform_visualizer.dart';

/// 오디오 파이프라인 타입
enum AudioPipelineType {
  sttBased,      // STT 기반 파이프라인
  directAudio,   // 직접 오디오 기반 파이프라인
}

/// 오디오 파이프라인 설정
class AudioPipelineConfig {
  final AudioPipelineType type;
  final AudioRecorderConfig recorderConfig;
  final AmplifierConfig amplifierConfig;
  final WaveformVisualizerConfig visualizerConfig;
  
  const AudioPipelineConfig({
    required this.type,
    required this.recorderConfig,
    required this.amplifierConfig,
    required this.visualizerConfig,
  });
  
  /// 기본 STT 파이프라인 설정
  factory AudioPipelineConfig.defaultSTT() {
    return AudioPipelineConfig(
      type: AudioPipelineType.sttBased,
      recorderConfig: const AudioRecorderConfig(
        samplingInterval: Duration(milliseconds: 30),
        sampleRate: 16000,
        channels: 1,
      ),
      amplifierConfig: const AmplifierConfig(
        amplificationFactor: 3.0,
        minThreshold: 0.02,
        maxThreshold: 1.0,
        quietBaseline: 0.005,
      ),
      visualizerConfig: const WaveformVisualizerConfig(
        maxBars: 50,
        enableSmoothing: true,
        smoothingFactor: 0.3,
      ),
    );
  }
  
  /// 기본 직접 오디오 파이프라인 설정
  factory AudioPipelineConfig.defaultDirect() {
    return AudioPipelineConfig(
      type: AudioPipelineType.directAudio,
      recorderConfig: const AudioRecorderConfig(
        samplingInterval: Duration(milliseconds: 50),
        sampleRate: 44100,
        channels: 2,
      ),
      amplifierConfig: const AmplifierConfig(
        amplificationFactor: 2.0,
        minThreshold: 0.01,
        maxThreshold: 1.0,
        quietBaseline: 0.001,
      ),
      visualizerConfig: const WaveformVisualizerConfig(
        maxBars: 100,
        enableSmoothing: true,
        smoothingFactor: 0.2,
      ),
    );
  }
}

/// 오디오 파이프라인 결과
class AudioPipeline {
  final IAudioRecorder recorder;
  final Amplifier amplifier;
  final WaveformVisualizer waveformVisualizer;
  
  const AudioPipeline({
    required this.recorder,
    required this.amplifier,
    required this.waveformVisualizer,
  });
  
  /// 파이프라인 시작
  Future<void> start() async {
    await recorder.startRecording();
  }
  
  /// 파이프라인 중지
  Future<void> stop() async {
    await recorder.stopRecording();
  }
  
  /// 파이프라인 정리
  Future<void> dispose() async {
    await recorder.dispose();
  }
}

/// 오디오 파이프라인 팩토리
class AudioPipelineFactory {
  /// STT 기반 파이프라인 생성
  static Future<AudioPipeline> createSTTPipeline({
    AudioPipelineConfig? config,
    SpeechToTextService? sttService,
  }) async {
    final pipelineConfig = config ?? AudioPipelineConfig.defaultSTT();
    final stt = sttService ?? SpeechToTextService();
    
    // 1. 녹음기 생성
    final recorder = SimpleSttRecorder(stt);
    await recorder.initialize(pipelineConfig.recorderConfig);
    
    // 2. Amplifier 생성
    final amplifier = Amplifier(pipelineConfig.amplifierConfig);
    
    // 3. WaveformVisualizer 생성
    final waveformVisualizer = WaveformVisualizer(pipelineConfig.visualizerConfig);
    
    // 4. 파이프라인 연결
    recorder.addObservee(amplifier);
    amplifier.addNextProcessor(waveformVisualizer);
    
    return AudioPipeline(
      recorder: recorder,
      amplifier: amplifier,
      waveformVisualizer: waveformVisualizer,
    );
  }
  
  /// 직접 오디오 기반 파이프라인 생성
  static Future<AudioPipeline> createDirectAudioPipeline({
    AudioPipelineConfig? config,
    AudioRecorderService? recorderService,
  }) async {
    final pipelineConfig = config ?? AudioPipelineConfig.defaultDirect();
    final audioService = recorderService ?? AudioRecorderService();
    
    // 1. 녹음기 생성
    final recorder = DirectAudioRecorder(audioService);
    await recorder.initialize(pipelineConfig.recorderConfig);
    
    // 2. Amplifier 생성
    final amplifier = Amplifier(pipelineConfig.amplifierConfig);
    
    // 3. WaveformVisualizer 생성
    final waveformVisualizer = WaveformVisualizer(pipelineConfig.visualizerConfig);
    
    // 4. 파이프라인 연결
    recorder.addObservee(amplifier);
    amplifier.addNextProcessor(waveformVisualizer);
    
    return AudioPipeline(
      recorder: recorder,
      amplifier: amplifier,
      waveformVisualizer: waveformVisualizer,
    );
  }
  
  /// 설정에 따른 자동 파이프라인 생성
  static Future<AudioPipeline> createPipeline({
    required AudioPipelineConfig config,
    SpeechToTextService? sttService,
    AudioRecorderService? recorderService,
  }) async {
    switch (config.type) {
      case AudioPipelineType.sttBased:
        return await createSTTPipeline(
          config: config,
          sttService: sttService,
        );
      case AudioPipelineType.directAudio:
        return await createDirectAudioPipeline(
          config: config,
          recorderService: recorderService,
        );
    }
  }
}