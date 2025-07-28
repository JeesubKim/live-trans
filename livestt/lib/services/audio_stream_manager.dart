import 'dart:async';
import 'dart:typed_data';
import '../utils/debug_logger.dart';

// Audio data wrapper with metadata
class AudioChunk {
  final Uint8List data;
  final DateTime timestamp;
  final double amplitude;
  final int sampleRate;

  AudioChunk({
    required this.data,
    required this.timestamp,
    required this.amplitude,
    this.sampleRate = 16000,
  });
}

// Audio stream manager - Pub/Sub hub
class AudioStreamManager {
  static final AudioStreamManager _instance = AudioStreamManager._internal();
  factory AudioStreamManager() => _instance;
  AudioStreamManager._internal();

  // Static empty data to avoid repeated allocations
  static final Uint8List _emptyData = Uint8List(0);

  // Main audio stream controller
  StreamController<AudioChunk>? _audioStreamController;
  
  // Multiple output streams for different subscribers
  final Map<String, StreamController<AudioChunk>> _subscribers = {};
  
  bool _isActive = false;
  
  // Input stream subscription
  StreamSubscription<double>? _amplitudeSubscription;

  bool get isActive => _isActive;
  
  // Start the audio stream manager
  Future<void> start() async {
    if (_isActive) {
      DebugLogger.log('AudioStreamManager already active');
      return;
    }

    // Create main stream controller
    _audioStreamController = StreamController<AudioChunk>.broadcast();
    
    _isActive = true;
    DebugLogger.info('AudioStreamManager started');
  }

  // Stop the audio stream manager
  Future<void> stop() async {
    if (!_isActive) return;

    _isActive = false;

    // Close amplitude subscription
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    // Close all subscriber streams
    for (final subscriber in _subscribers.values) {
      await subscriber.close();
    }
    _subscribers.clear();

    // Close main stream
    await _audioStreamController?.close();
    _audioStreamController = null;

    DebugLogger.info('AudioStreamManager stopped');
  }

  // Subscribe to audio stream with a unique ID
  Stream<AudioChunk>? subscribe(String subscriberId) {
    if (!_isActive) {
      DebugLogger.log('AudioStreamManager not active');
      return null;
    }

    // Create dedicated stream for this subscriber
    final controller = StreamController<AudioChunk>();
    _subscribers[subscriberId] = controller;

    // Forward main stream data to this subscriber
    _audioStreamController?.stream.listen(
      (audioChunk) {
        if (!controller.isClosed) {
          controller.add(audioChunk);
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    DebugLogger.log('Subscriber "$subscriberId" added');
    return controller.stream;
  }

  // Unsubscribe a specific subscriber
  Future<void> unsubscribe(String subscriberId) async {
    final controller = _subscribers.remove(subscriberId);
    if (controller != null) {
      await controller.close();
      DebugLogger.log('Subscriber "$subscriberId" removed');
    }
  }

  // Publish audio data to all subscribers
  void publishAudioChunk(AudioChunk audioChunk) {
    if (!_isActive || _audioStreamController?.isClosed == true) {
      return;
    }

    try {
      _audioStreamController?.add(audioChunk);
    } catch (e) {
      DebugLogger.error('Error publishing audio chunk: $e');
    }
  }

  // Connect to AudioRecorderService for amplitude data
  void connectToAmplitudeStream(Stream<double> amplitudeStream) {
    _amplitudeSubscription = amplitudeStream.listen(
      (amplitude) {
        // Create optimized audio chunk with amplitude data only
        // Use static empty data to avoid repeated allocations
        final audioChunk = AudioChunk(
          data: _emptyData, // Reuse static empty data
          timestamp: DateTime.now(),
          amplitude: amplitude,
        );
        
        publishAudioChunk(audioChunk);
      },
      onError: (error) {
        DebugLogger.error('Amplitude stream error: $error');
      },
    );
  }

  // Get current subscriber count
  int get subscriberCount => _subscribers.length;

  // Get subscriber IDs
  List<String> get subscriberIds => _subscribers.keys.toList();

  // Dispose all resources
  Future<void> dispose() async {
    await stop();
  }
}