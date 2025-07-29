import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../setting/settings_screen.dart';
import '../../utils/global_toast.dart';
import '../../services/subtitle_display_manager.dart';
import '../../services/subtitle_file_manager.dart';
import '../../services/app_settings_service.dart';
import '../../services/audio_file_service.dart';
import '../../core/models/settings.dart';
import '../../utils/debug_logger.dart';
import '../../components/subtitifying_component.dart';
import '../../components/audio_waveform_component.dart';
import '../../core/audio/audio_pipeline_factory.dart';
import '../../core/audio/processors/waveform_visualizer.dart';
import '../../core/audio/recorders/simple_stt_recorder.dart';

class RecordingScreen extends StatefulWidget {
  final String selectedLanguage;
  final String selectedModel;
  
  const RecordingScreen({
    super.key,
    required this.selectedLanguage,
    required this.selectedModel,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> 
    with TickerProviderStateMixin {
  
  // Animation for blinking recording indicator
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  
  // Control overlay animations
  late AnimationController _controlsController;
  late Animation<Offset> _topSlideAnimation;
  late Animation<Offset> _bottomSlideAnimation;
  
  // Control overlay visibility
  bool _showControls = false;
  Timer? _autoHideTimer;
  
  // STT states
  bool _isListening = false;
  bool _isPaused = false;
  String _currentText = '';
  late String _selectedLanguage;
  late String _selectedModel;
  final List<String> _captionHistory = [];
  double _fontSize = 72.0;
  
  // Font size preview
  bool _showFontPreview = false;
  Timer? _fontPreviewTimer;
  late AnimationController _fontPreviewController;
  late Animation<double> _fontPreviewAnimation;
  
  // Audio pipeline
  AudioPipeline? _audioPipeline;
  StreamSubscription<WaveformData>? _waveformSubscription;
  
  // Waveform and timer
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  List<double> _waveformData = [];
  final int _maxWaveformBars = 50; // Maximum number of bars to display
  
  // Services
  late SubtitleDisplayManager _subtitleManager;
  final SubtitleFileManager _fileManager = SubtitleFileManager();
  final AppSettingsService _settings = AppSettingsService();
  final AudioFileService _audioFileService = AudioFileService();
  
  // Subtitle streams
  StreamSubscription<List<SubtitleItem>>? _historySubscription;
  StreamSubscription<SubtitleItem?>? _currentSubscription;
  StreamSubscription<String>? _realtimeSubscription;
  
  // Subtitle display data
  SubtitleItem? _currentSubtitle;
  String _realtimeSubtitle = '';
  final ScrollController _subtitleScrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize selected values from widget parameters
    _selectedLanguage = widget.selectedLanguage;
    _selectedModel = 'Android STT Engine'; // Always use Android default
    
    // Initialize subtitle manager (will be replaced with STT's manager later)
    _subtitleManager = SubtitleDisplayManager();
    
    DebugLogger.info('🔄 RecordingScreen initialized with language: $_selectedLanguage, model: $_selectedModel');
    
    // Set up blinking animation
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));
    
    // Set up controls slide animations
    _controlsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _topSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controlsController,
      curve: Curves.easeInOut,
    ));
    _bottomSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controlsController,
      curve: Curves.easeInOut,
    ));
    
    // Set up font preview fade animation
    _fontPreviewController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fontPreviewAnimation = Tween<double>(
      begin: 0.0,
      end: 0.2,
    ).animate(CurvedAnimation(
      parent: _fontPreviewController,
      curve: Curves.easeOut,
    ));
    
    // Initialize everything after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAllServices();
    });
  }
  
  @override
  void dispose() {
    DebugLogger.info('🔄 Disposing RecordingScreen...');
    
    // Cancel timers first
    _autoHideTimer?.cancel();
    _fontPreviewTimer?.cancel();
    _recordingTimer?.cancel();
    
    // Cancel new pipeline streams
    _waveformSubscription?.cancel();
    
    // Cancel subtitle streams
    _historySubscription?.cancel();
    _currentSubscription?.cancel();
    _realtimeSubscription?.cancel();
    
    // Dispose animations
    _blinkController.dispose();
    _controlsController.dispose();
    _fontPreviewController.dispose();
    
    // Dispose ScrollController to prevent memory leaks
    _subtitleScrollController.dispose();
    
    // Start async dispose process (fire and forget)
    _disposeAsync();
    
    super.dispose();
  }
  
  // Async dispose for all async resources
  Future<void> _disposeAsync() async {
    try {
      // Dispose subtitle manager first
      await _subtitleManager.dispose();
      
      // Dispose audio pipeline
      await _audioPipeline?.dispose();
      
      // Dispose audio file service
      _audioFileService.dispose();
      
      DebugLogger.info('✅ RecordingScreen async disposal completed');
    } catch (e) {
      DebugLogger.error('Error during async disposal: $e');
    }
  }
  
  void _startAutoHideControls() {
    // Cancel existing timer if any
    _autoHideTimer?.cancel();
    
    // Start new timer
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _showControls) {
        _hideControls();
      }
    });
  }
  
  void _showControlsAnimated() {
    setState(() {
      _showControls = true;
    });
    _controlsController.forward();
    _startAutoHideControls();
  }
  
  void _resetAutoHideTimer() {
    if (_showControls) {
      _startAutoHideControls();
    }
  }
  
  void _showFontSizePreview() {
    // Cancel existing preview timer
    _fontPreviewTimer?.cancel();
    
    // Always show preview when font size changes
    if (_currentText.isEmpty) {
      setState(() {
        _showFontPreview = true;
      });
      
      // Reset animation to show immediately
      _fontPreviewController.reset();
      
      // Start fade out after 3 seconds
      _fontPreviewTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _fontPreviewController.forward().then((_) {
            if (mounted) {
              setState(() {
                _showFontPreview = false;
              });
            }
          });
        }
      });
    }
    // Force immediate rebuild for current text (no animation delay)
    setState(() {});
  }
  
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isListening && !_isPaused) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      } else {
        // Stop timer if not actively recording to save battery
        timer.cancel();
      }
    });
  }

  
  // Initialize and start audio pipeline
  Future<void> _initializeAudioPipeline() async {
    try {
      // Create STT-based audio pipeline
      _audioPipeline = await AudioPipelineFactory.createSTTPipeline();
      
      // Initialize our SubtitleDisplayManager with auto-save
      await _subtitleManager.initialize();
      final sessionId = await _subtitleManager.startSession();
      
      if (sessionId != null) {
        DebugLogger.info('✅ Session started successfully: $sessionId');
      } else {
        DebugLogger.error('❌ Failed to start session');
      }
      
      // CRITICAL: Provide our SubtitleDisplayManager to SimpleSttRecorder
      final recorder = _audioPipeline!.recorder;
      if (recorder is SimpleSttRecorder) {
        // Replace STT's SubtitleDisplayManager with ours
        recorder.setSubtitleManager(_subtitleManager);
        DebugLogger.info('🔗 Provided auto-save SubtitleDisplayManager to STT');
        DebugLogger.info('📊 Session active: ${_subtitleManager.isSessionActive}');
      }
      
      // Subscribe to waveform data from pipeline
      _waveformSubscription = _audioPipeline!.waveformVisualizer.waveformStream.listen(
        (waveformData) {
          if (mounted) {
            setState(() {
              _waveformData = waveformData.amplitudes;
            });
          }
        },
        onError: (error) {
          DebugLogger.error('Waveform stream error: $error');
        },
      );
      
      // Subscribe to subtitle streams (now using STT's SubtitleDisplayManager)
      _subscribeToSubtitles();
      
      // Start the pipeline
      await _audioPipeline!.start();
      
      setState(() {
        _isListening = true;
      });
      
      _blinkController.repeat(reverse: true);
      _startRecordingTimer();
      
      DebugLogger.info('Audio pipeline initialized and started');
    } catch (e) {
      DebugLogger.error('Error initializing audio pipeline: $e');
      setState(() {
        _isListening = false;
      });
      rethrow;
    }
  }


  // Subscribe to subtitle streams from SubtitleDisplayManager
  void _subscribeToSubtitles() {
    // Subscribe to subtitle history
    _historySubscription = _subtitleManager.historyStream.listen(
      (history) {
        if (mounted) {
          // History is now managed by SubtitleDisplayManager
          DebugLogger.info('Subtitle history updated: ${history.length} items');
        }
      },
      onError: (error) {
        DebugLogger.error('Subtitle history stream error: $error');
      },
    );

    // Subscribe to current subtitle (confirmed text replaces realtime display)
    _currentSubscription = _subtitleManager.currentStream.listen(
      (current) {
        if (mounted) {
          setState(() {
            _currentSubtitle = current;
            // When text is confirmed, replace realtime display with confirmed text
            if (current != null && current.text.isNotEmpty) {
              _realtimeSubtitle = current.text;
            }
          });
          DebugLogger.info('🖥️ UI Current subtitle confirmed, replacing realtime display: "${current?.text ?? "null"}"');
          
          // Auto-scroll to bottom to show latest subtitle
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_subtitleScrollController.hasClients) {
              _subtitleScrollController.animateTo(
                _subtitleScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          DebugLogger.warning('⚠️ UI not mounted, skipping current update: "${current?.text ?? "null"}"');
        }
      },
      onError: (error) {
        DebugLogger.error('Current subtitle stream error: $error');
      },
    );

    // Subscribe to realtime text
    _realtimeSubscription = _subtitleManager.realtimeStream.listen(
      (realtime) {
        if (mounted) {
          setState(() {
            _realtimeSubtitle = realtime;
          });
          DebugLogger.info('🖥️ UI Realtime subtitle updated: "$realtime"');
          
          // Auto-scroll to bottom to show latest realtime text
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_subtitleScrollController.hasClients) {
              _subtitleScrollController.animateTo(
                _subtitleScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          DebugLogger.warning('⚠️ UI not mounted, skipping realtime update: "$realtime"');
        }
      },
      onError: (error) {
        DebugLogger.error('Realtime subtitle stream error: $error');
      },
    );
  }

  // Update subtitle configuration based on orientation
  void _updateSubtitleConfiguration() {
    final orientation = MediaQuery.of(context).orientation;
    final size = MediaQuery.of(context).size;
    _subtitleManager.updateConfiguration(
      orientation: orientation,
      screenSize: size,
    );
  }

  // Initialize all services in proper order
  Future<void> _initializeAllServices() async {
    try {
      DebugLogger.info('🚀 Starting service initialization...');
      
      // 1. Initialize settings first
      try {
        await _initializeSettings();
      } catch (e) {
        DebugLogger.warning('⚠️ Settings initialization failed, using defaults: $e');
        // Continue with defaults if settings fail
      }
      
      // 2. Initialize audio file service
      try {
        await _audioFileService.initialize();
      } catch (e) {
        DebugLogger.warning('⚠️ Audio file service initialization failed: $e');
        globalToast.warning('File saving may not work properly');
        // Continue without file service
      }
      
      // 3. Initialize and start audio pipeline
      await _initializeAudioPipeline();
      
      DebugLogger.info('✅ All services initialized successfully');
    } catch (e) {
      DebugLogger.error('❌ Critical error initializing services: $e');
      
      // Reset listening state on critical error
      if (mounted) {
        setState(() {
          _isListening = false;
          _isPaused = false;
        });
      }
      
      // Show user-friendly error message
      String userMessage = _getUserFriendlyInitError(e.toString());
      globalToast.error(userMessage);
    }
  }
  
  // Convert technical initialization errors to user-friendly messages
  String _getUserFriendlyInitError(String error) {
    if (error.contains('permission')) {
      return 'Microphone permission required. Please grant permission and try again.';
    } else if (error.contains('network') || error.contains('internet')) {
      return 'Network connection required for speech recognition. Please check your internet.';
    } else if (error.contains('speech') || error.contains('STT')) {
      return 'Speech recognition service unavailable. Please restart the app.';
    } else {
      return 'Initialization failed. Please restart the app and try again.';
    }
  }

  // Initialize settings service
  Future<void> _initializeSettings() async {
    try {
      await _settings.initialize();
      DebugLogger.info('Settings service initialized');
    } catch (e) {
      DebugLogger.error('Error initializing settings: $e');
    }
  }








  // Stop audio pipeline recording
  Future<void> _stopRecording() async {
    try {
      // Stop the audio pipeline
      await _audioPipeline?.stop();
      
      setState(() {
        _isListening = false;
        _isPaused = false;
      });
      
      _blinkController.stop();
      _recordingTimer?.cancel();
      _historySubscription?.cancel();
      _currentSubscription?.cancel();
      _realtimeSubscription?.cancel();
      
      // Get session info before stopping
      final sessionInfo = _subtitleManager.currentSessionInfo;
      final subtitleCount = sessionInfo?['subtitleCount'] ?? 0;
      
      if (subtitleCount > 0) {
        DebugLogger.info('📝 Recording stopped with $subtitleCount auto-saved subtitles');
        globalToast.success('Recording stopped ($subtitleCount subtitles auto-saved)');
      } else {
        DebugLogger.info('📝 Recording stopped (no subtitles)');
        globalToast.success('Recording stopped');
        // End session without saving if no subtitles
        await _subtitleManager.endSession(save: false);
      }
    } catch (e) {
      DebugLogger.error('Error stopping recording: $e');
      globalToast.error('Stop recording error: $e');
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
  
  
  void _hideControls() {
    _autoHideTimer?.cancel();
    _controlsController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }
  
  void _toggleListening() async {
    if (_isListening) {
      // When stopping, show save dialog
      _stopRecording();
      
      // Get full history for saving
      final fullHistory = _subtitleManager.getFullHistory();
      _captionHistory.clear();
      _captionHistory.addAll(fullHistory.map((item) => item.text));
      // Show save dialog when stopping
      _showSaveDialog();
    } else {
      // When starting, create a new SubtitleDisplayManager instance
      await _subtitleManager.dispose();
      _subtitleManager = SubtitleDisplayManager();
      _initializeAudioPipeline();
    }
  }
  
  void _togglePause() async {
    if (_isPaused) {
      // Resume recording - restart the pipeline
      await _audioPipeline?.start();
      setState(() {
        _isPaused = false;
      });
      _blinkController.repeat(reverse: true);
    } else {
      // Pause recording - stop the pipeline
      await _audioPipeline?.stop();
      setState(() {
        _isPaused = true;
      });
      _blinkController.stop();
    }
    _resetAutoHideTimer();
  }
  
  void _showSaveDialog() {
    final now = DateTime.now();
    final defaultTitle = 'Recording ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: animation, 
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => _SaveRecordingDialog(
        defaultTitle: defaultTitle,
        captionHistory: _captionHistory,
        onSave: (title, category) async {
          try {
            // End session with save using new system
            final filePath = await _subtitleManager.endSession(
              save: true,
              title: title,
              category: category,
              language: _selectedLanguage,
              model: _selectedModel,
              duration: _recordingDuration,
            );
            
            if (filePath != null) {
              globalToast.success('Recording saved: $title');
              DebugLogger.info('Session saved to: $filePath');
              // Close dialog and return to main screen
              Navigator.of(context).popUntil((route) => route.isFirst);
              return null; // Success - close dialog
            } else {
              // Return error message to keep dialog open
              return 'No subtitles to save. Please record some speech first.';
            }
            
          } catch (e) {
            DebugLogger.error('Error saving session: $e');
            // Return error message to keep dialog open
            return 'Failed to save recording: ${e.toString()}';
          }
        },
        onDiscard: () {
          _showDiscardConfirmation();
        },
        onResume: () {
          // Resume recording when X is pressed
          setState(() {
            _isPaused = false;
            _isListening = true;  // Ensure listening state is true
            _blinkController.repeat(reverse: true);
          });
          Navigator.of(context).pop();
        },
        context: context,
      ),
    );
  }
  
  void _showDiscardConfirmation() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: animation, 
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => _DiscardConfirmationDialog(
        onConfirm: () async {
          try {
            // End session without saving (discard temp files)
            await _subtitleManager.endSession(save: false);
            
            setState(() {
              _captionHistory.clear();
              _currentText = '';
            });
            
            // Close all dialogs and go back to start screen
            Navigator.of(context).popUntil((route) => route.isFirst);
            globalToast.success('Recording discarded');
            
          } catch (e) {
            DebugLogger.error('Error discarding session: $e');
            globalToast.error('Failed to discard recording');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isListening,
      onPopInvoked: (didPop) {
        // Handle back button like Stop button
        if (!didPop && _isListening) {
          _toggleListening();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: OrientationBuilder(
        builder: (context, orientation) {
          return Stack(
            children: [
              // Main content area
              GestureDetector(
                onTap: () {
                  if (_showControls) {
                    _hideControls();
                  } else {
                    _showControlsAnimated();
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                  child: _buildCaptionDisplay(orientation),
                ),
              ),
              
              // Waveform and timer (top left)
              if (_isListening)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20,
                  right: 180, // Leave space for Subtitifying indicator (approx 140px) + margin
                  child: AudioWaveformComponent.recording(
                    recordingDuration: _recordingDuration,
                    waveformData: _waveformData,
                    maxWaveformBars: _maxWaveformBars,
                    isPaused: _isPaused,
                  ),
                ),
              
              // Top recording indicator (always visible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                right: 20,
                child: SubtitifyingComponent(
                  isListening: _isListening,
                  isPaused: _isPaused,
                  blinkAnimation: _blinkAnimation,
                ),
              ),
              
              // Control overlay with slide animations
              if (_showControls) ...[
                // Semi-transparent background
                GestureDetector(
                  onTap: _hideControls,
                  child: Container(
                    color: Colors.black26, // More transparent
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                
                // Top controls
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: _topSlideAnimation,
                    child: _buildTopControls(),
                  ),
                ),
                
                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: _bottomSlideAnimation,
                    child: _buildBottomControls(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      ),
    );
  }
  
  Widget _buildCaptionDisplay(Orientation orientation) {
    final isLandscape = orientation == Orientation.landscape;
    final baseFontSize = isLandscape ? _fontSize + 8.0 : _fontSize;
    
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Container(),
            ),
        
        ],
        ),
        
        // Current subtitle display (centered) - simplified, no history
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6, // Max 60% of screen height
            ),
            child: SingleChildScrollView(
              controller: _subtitleScrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Realtime text (being typed) - main subtitle with enhanced styling
                if (_realtimeSubtitle.isNotEmpty || _showFontPreview)
                  AnimatedBuilder(
                    animation: _fontPreviewAnimation,
                    builder: (context, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: _realtimeSubtitle.isNotEmpty 
                              ? Colors.black.withOpacity(0.4)
                              : Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _realtimeSubtitle.isNotEmpty ? _realtimeSubtitle : 'Subtitify...',
                          style: TextStyle(
                            color: _realtimeSubtitle.isNotEmpty 
                                ? Colors.white
                                : Colors.white.withOpacity(_fontPreviewAnimation.value),
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        
        
        // Status text below Subtitify indicator
        Positioned(
          top: MediaQuery.of(context).padding.top + 68,
          right: 20,
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(8),
            child: Text(
              _isPaused 
                ? 'Paused - Tap screen for controls'
                : _isListening 
                  ? 'Subtitifying - Tap screen for controls'
                  : 'Tap screen for controls',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTopControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // More transparent
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Softer shadow
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // Empty space to balance the layout
              const Text(
                'SUBTITIFY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // More transparent
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Softer shadow
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
            final screenHeight = MediaQuery.of(context).size.height;
            
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * (isPortrait ? 0.45 : 0.6), // More space in landscape
                ),
                child: Padding(
                  padding: EdgeInsets.all(isPortrait ? 20 : 12),
                  child: isPortrait ? _buildPortraitControls() : _buildLandscapeControls(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildPortraitControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLanguageSelector(),
        const SizedBox(height: 20),
        _buildModelSelector(),
        const SizedBox(height: 20),
        _buildFontSizeControl(),
        const SizedBox(height: 20),
        _buildControlButtons(),
      ],
    );
  }
  
  Widget _buildLandscapeControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Dropdowns
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Language and Model in same row
                  Row(
                    children: [
                      Expanded(child: _buildLanguageSelector()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModelSelector()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFontSizeControl(),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right side - Control buttons
            Expanded(
              flex: 1,
              child: Center(
                child: _buildControlButtons(),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              dropdownColor: Colors.grey[800]!.withOpacity(0.9),
              style: const TextStyle(color: Colors.white),
              underline: Container(),
              isExpanded: true,
              items: SttLanguage.values.map((lang) => 
                DropdownMenuItem(value: lang.displayName, child: Text(lang.displayName))
              ).toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                  
                  // Save to settings
                  final settings = AppSettingsService();
                  await settings.setSelectedLanguage(value);
                  
                  globalToast.normal('Language changed to $_selectedLanguage');
                  _resetAutoHideTimer();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedModel,
              dropdownColor: Colors.grey[800]!.withOpacity(0.9),
              style: const TextStyle(color: Colors.white),
              underline: Container(),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Android STT Engine', child: Text('Android STT Engine')),
                DropdownMenuItem(value: 'Device Default', child: Text('Device Default (Same as above)')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedModel = value!;
                });
                globalToast.normal(
                  'STT model changed to $_selectedModel'
                );
                _resetAutoHideTimer();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFontSizeControl() {
    return Row(
      children: [
        const Icon(Icons.text_fields, color: Colors.white),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            setState(() {
              _fontSize = (_fontSize - 2).clamp(12.0, 140.0);
            });
            _showFontSizePreview();
            _resetAutoHideTimer();
          },
          icon: const Icon(Icons.remove, color: Colors.white),
        ),
        Expanded(
          child: Slider(
            value: _fontSize,
            min: 12.0,
            max: 140.0,
            divisions: 64,
            activeColor: Colors.white,
            inactiveColor: Colors.grey,
            onChanged: (value) {
              setState(() {
                _fontSize = value;
              });
              _showFontSizePreview();
              _resetAutoHideTimer();
            },
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _fontSize = (_fontSize + 2).clamp(12.0, 140.0);
            });
            _showFontSizePreview();
            _resetAutoHideTimer();
          },
          icon: const Icon(Icons.add, color: Colors.white),
        ),
        Text(
          '${_fontSize.round()}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isListening && !_isPaused) ...[
          _buildControlButton(
            icon: Icons.pause,
            label: 'Pause',
            isActive: false,
            onPressed: () {
              _togglePause();
              _resetAutoHideTimer();
            },
          ),
          const SizedBox(width: 20),
        ],
        if (_isListening && _isPaused) ...[
          _buildControlButton(
            icon: Icons.play_arrow,
            label: 'Resume',
            isActive: true,
            onPressed: () {
              _togglePause();
              _resetAutoHideTimer();
            },
          ),
          const SizedBox(width: 20),
        ],
        _buildControlButton(
          icon: _isListening ? Icons.stop : Icons.mic,
          label: _isListening ? 'Stop' : 'Start',
          isActive: _isListening && !_isPaused,
          onPressed: () {
            _toggleListening();
            _resetAutoHideTimer();
          },
        ),
      ],
    );
  }
  
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        final buttonSize = isPortrait ? 60.0 : 50.0;
        final iconSize = isPortrait ? 28.0 : 24.0;
        final fontSize = isPortrait ? 12.0 : 10.0;
        
        return Column(
          children: [
            GestureDetector(
              onTap: onPressed,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: isActive ? Colors.red.withOpacity(0.8) : Colors.grey[700]!.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
            SizedBox(height: isPortrait ? 8 : 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
              ),
            ),
          ],
        );
      },
    );
  }
  
}

// Save Recording Dialog
class _SaveRecordingDialog extends StatefulWidget {
  final String defaultTitle;
  final List<String> captionHistory;
  final Future<String?> Function(String title, String category) onSave;
  final VoidCallback onDiscard;
  final VoidCallback onResume;
  final BuildContext context;

  const _SaveRecordingDialog({
    required this.defaultTitle,
    required this.captionHistory,
    required this.onSave,
    required this.onDiscard,
    required this.onResume,
    required this.context,
  });

  @override
  State<_SaveRecordingDialog> createState() => _SaveRecordingDialogState();
}

class _SaveRecordingDialogState extends State<_SaveRecordingDialog> {
  late TextEditingController _titleController;
  String _selectedCategory = 'Meeting';
  String? _errorMessage;
  bool _isSaving = false;
  
  final List<String> _categories = [
    'Meeting',
    'Lecture',
    'Interview',
    'Personal',  
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with X button
                Row(
                  children: [
                    const Icon(Icons.save, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Save Recording',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onResume,
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Resume Recording',
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Recording info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recording Summary',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.captionHistory.length} text segments captured',
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (widget.captionHistory.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Preview: ${widget.captionHistory.first.substring(0, widget.captionHistory.first.length > 50 ? 50 : widget.captionHistory.first.length)}...',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Title input
                const Text(
                  'Title',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter recording title',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Category selection
                const Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[600]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    underline: Container(),
                    dropdownColor: Colors.grey[800]!.withOpacity(0.9),
                    style: const TextStyle(color: Colors.white),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDiscard,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Discard'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () async {
                          setState(() {
                            _isSaving = true;
                            _errorMessage = null;
                          });
                          
                          try {
                            // Use default title if empty
                            final title = _titleController.text.trim().isEmpty 
                                ? widget.defaultTitle 
                                : _titleController.text.trim();
                            final errorMessage = await widget.onSave(title, _selectedCategory);
                            
                            if (errorMessage == null) {
                              // Success - dialog will be closed by onSave callback
                              return;
                            } else {
                              // Error - show message and keep dialog open
                              setState(() {
                                _errorMessage = errorMessage;
                                _isSaving = false;
                              });
                            }
                          } catch (e) {
                            setState(() {
                              _errorMessage = 'Unexpected error: ${e.toString()}';
                              _isSaving = false;
                            });
                            DebugLogger.error('Save dialog error: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isSaving 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Discard Confirmation Dialog with Slide to Delete
class _DiscardConfirmationDialog extends StatefulWidget {
  final VoidCallback onConfirm;

  const _DiscardConfirmationDialog({
    required this.onConfirm,
  });

  @override
  State<_DiscardConfirmationDialog> createState() => _DiscardConfirmationDialogState();
}

class _DiscardConfirmationDialogState extends State<_DiscardConfirmationDialog> 
    with TickerProviderStateMixin {
  double _slideValue = 0.0;
  bool _isFullySlided = false;
  late AnimationController _colorController;
  late Animation<double> _colorAnimation;
  
  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _colorAnimation = Tween<double>(
      begin: 0.2,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning,
                color: Colors.white,
                size: 32,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            const Text(
              'Discard Recording?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              'This action cannot be undone. All captured text will be permanently deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Slide to delete
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxSlide = constraints.maxWidth - 56; // 4px padding on both sides + 48px for icon area
                  return Stack(
                    children: [
                      // Background text
                      const Center(
                        child: Text(
                          'Slide to Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // Sliding track fill with trash icon
                      Positioned(
                        left: 4,
                        top: 4,
                        bottom: 4,
                        width: (_slideValue + 52).clamp(0, constraints.maxWidth - 8),
                        child: GestureDetector(
                          onPanStart: (_) {
                            // Start sliding
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _slideValue = (_slideValue + details.delta.dx)
                                  .clamp(0.0, maxSlide);
                              
                              // Check if fully slided (100%)
                              if (_slideValue >= maxSlide) {
                                if (!_isFullySlided) {
                                  _isFullySlided = true;
                                  _colorController.forward();
                                }
                              } else {
                                if (_isFullySlided) {
                                  _isFullySlided = false;
                                  _colorController.reverse();
                                }
                              }
                            });
                          },
                          onPanEnd: (_) {
                            setState(() {
                              // If fully slided when touch is released, execute delete
                              if (_isFullySlided) {
                                widget.onConfirm();
                                // Don't call pop here as onConfirm already handles navigation
                              } else {
                                // Reset to start position
                                _slideValue = 0.0;
                                _colorController.reverse();
                              }
                            });
                          },
                          child: AnimatedBuilder(
                            animation: _colorAnimation,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(_colorAnimation.value),
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(right: 16),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Cancel button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

