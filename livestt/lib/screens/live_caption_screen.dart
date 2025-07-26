import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recordings_screen.dart';
import 'settings_screen.dart';
import '../widgets/global_toast.dart';

class LiveCaptionScreen extends StatefulWidget {
  final String selectedLanguage;
  final String selectedModel;
  
  const LiveCaptionScreen({
    super.key,
    required this.selectedLanguage,
    required this.selectedModel,
  });

  @override
  State<LiveCaptionScreen> createState() => _LiveCaptionScreenState();
}

class _LiveCaptionScreenState extends State<LiveCaptionScreen> 
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
  
  // Waveform and timer
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Timer? _waveformTimer;
  List<double> _waveformData = [];
  final int _maxWaveformBars = 50; // Maximum number of bars to display
  
  @override
  void initState() {
    super.initState();
    
    // Initialize selected values from widget parameters
    _selectedLanguage = widget.selectedLanguage;
    _selectedModel = widget.selectedModel;
    
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
    
    // Start recording automatically and start blinking
    _isListening = true;
    _blinkController.repeat(reverse: true);
    
    // Start recording timer and waveform simulation
    _startRecordingTimer();
    _startWaveformSimulation();
    
  }
  
  @override
  void dispose() {
    _blinkController.dispose();
    _controlsController.dispose();
    _fontPreviewController.dispose();
    _autoHideTimer?.cancel();
    _fontPreviewTimer?.cancel();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    super.dispose();
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
      }
    });
  }
  
  void _startWaveformSimulation() {
    // Start timer to add new waveform data every 100ms (simulating real-time audio input)
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _isListening && !_isPaused) {
        setState(() {
          // Add new random value to simulate incoming audio level
          final newValue = math.Random().nextDouble() * 0.8 + 0.2; // Values between 0.2 and 1.0
          _waveformData.add(newValue);
          
          // Keep only the latest bars (sliding window effect)
          if (_waveformData.length > _maxWaveformBars) {
            _waveformData.removeAt(0);
          }
        });
      }
    });
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
  
  void _toggleListening() {
    setState(() {
      if (_isListening) {
        // When stopping, pause and show save dialog
        _isPaused = true;
        _blinkController.stop();
        _waveformTimer?.cancel();
        if (_currentText.isNotEmpty) {
          _captionHistory.add(_currentText);
          _currentText = '';
        }
        // Show save dialog when stopping
        _showSaveDialog();
      } else {
        // When starting
        _isListening = true;
        _isPaused = false;
        _blinkController.repeat(reverse: true);
        _startWaveformSimulation();
        // Simulate speech recognition with sample text after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isListening && !_isPaused) {
            setState(() {
              _currentText = 'This is a sample caption text for demonstration...';
            });
          }
        });
      }
    });
  }
  
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _blinkController.stop();
        _waveformTimer?.cancel();
      } else {
        if (_isListening) {
          _blinkController.repeat(reverse: true);
          _startWaveformSimulation();
        }
      }
    });
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
        onSave: (title, category) {
          // Handle save logic here
          TOAST.sendMessage(MessageType.success, 'Recording saved as: $title');
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
        onConfirm: () {
          setState(() {
            _captionHistory.clear();
            _currentText = '';
          });
          // Close all dialogs and go back to start screen
          Navigator.of(context).popUntil((route) => route.isFirst);
          TOAST.sendMessage(MessageType.success, 'Recording discarded');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button like Stop button
        if (_isListening) {
          _toggleListening();
          return false; // Don't pop immediately, let save dialog handle it
        }
        return true; // Allow normal back navigation if not listening
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
                  child: _buildWaveformTimer(),
                ),
              
              // Top recording indicator (always visible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                right: 20,
                child: AnimatedBuilder(
                  animation: _blinkAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isListening && !_isPaused
                            ? Colors.red.withOpacity(_blinkAnimation.value * 0.3 + 0.1)
                            : Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isListening && !_isPaused ? Colors.red.withOpacity(_blinkAnimation.value) : Colors.grey,
                          width: _isListening && !_isPaused ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.record_voice_over,
                            color: _isListening && !_isPaused ? Colors.red.withOpacity(_blinkAnimation.value) : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          AnimatedBuilder(
                            animation: _blinkAnimation,
                            builder: (context, child) {
                              return Text(
                                _isListening && !_isPaused ? 'Subtitifying' : 'Subtitify',
                                style: TextStyle(
                                  color: _isListening && !_isPaused 
                                      ? Colors.white.withOpacity(_blinkAnimation.value)
                                      : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isListening && !_isPaused ? Colors.red.withOpacity(_blinkAnimation.value) : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
        
        // Current caption or font preview (centered)
        if (_currentText.isNotEmpty || _showFontPreview)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedBuilder(
                animation: _fontPreviewAnimation,
                builder: (context, child) {
                  return Text(
                    _currentText.isNotEmpty ? _currentText : 'Subtitify...',
                    style: TextStyle(
                      color: _currentText.isNotEmpty 
                          ? Colors.white 
                          : Colors.white70,
                      fontSize: baseFontSize,
                      fontWeight: FontWeight.w500,
                      height: 0.9,
                      shadows: const [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
        
        // Caption history
        if (_captionHistory.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              height: isLandscape ? 150 : 100,
              child: ListView.builder(
                reverse: true,
                itemCount: _captionHistory.length,
                itemBuilder: (context, index) {
                  final reversedIndex = _captionHistory.length - 1 - index;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _captionHistory[reversedIndex],
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: baseFontSize * 0.8,
                        height: 1.3,
                        shadows: const [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
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
              style: TextStyle(
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
              items: const [
                DropdownMenuItem(value: 'English (US)', child: Text('English (US)')),
                DropdownMenuItem(value: 'Korean', child: Text('Korean')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                TOAST.sendMessage(
                  MessageType.normal, 
                  'Language changed to $_selectedLanguage'
                );
                _resetAutoHideTimer();
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
                DropdownMenuItem(value: 'Whisper Base', child: Text('Whisper Base')),
                DropdownMenuItem(value: 'Whisper Small', child: Text('Whisper Small')),
                DropdownMenuItem(value: 'Whisper Medium', child: Text('Whisper Medium')),
                DropdownMenuItem(value: 'Whisper Large', child: Text('Whisper Large')),
                DropdownMenuItem(value: 'Device Default', child: Text('Device Default')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedModel = value!;
                });
                TOAST.sendMessage(
                  MessageType.normal, 
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
  
  Widget _buildWaveformTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Same padding as Subtitifying
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isListening && !_isPaused ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.2), 
          width: 2, // Same thickness as Subtitifying indicator
        ),
      ),
      child: Row(
        children: [
          // Timer
          Text(
            _formatDuration(_recordingDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          // Waveform (flatter and wider)
          Expanded(
            child: SizedBox(
              height: 14, // Reduced from 20 to make it flatter
              child: CustomPaint(
                painter: WaveformPainter(
                  waveformData: _waveformData,
                  maxBars: _maxWaveformBars,
                  isPaused: _isPaused,
                ),
                size: const Size.fromHeight(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Save Recording Dialog
class _SaveRecordingDialog extends StatefulWidget {
  final String defaultTitle;
  final List<String> captionHistory;
  final Function(String title, String category) onSave;
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
                        onPressed: () {
                          widget.onSave(_titleController.text, _selectedCategory);
                          // Go back to main screen (StartScreen)
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Save'),
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
  bool _isSliding = false;
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
                            setState(() {
                              _isSliding = true;
                            });
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
                              _isSliding = false;
                              
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
                                    Padding(
                                      padding: const EdgeInsets.only(right: 16),
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

// Waveform painter with real-time scrolling effect
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final int maxBars;
  final bool isPaused;

  WaveformPainter({
    required this.waveformData,
    required this.maxBars,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final activePaint = Paint()
      ..color = isPaused ? Colors.grey.withOpacity(0.4) : Colors.blue
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = isPaused ? Colors.grey.withOpacity(0.2) : Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / maxBars;
    final centerY = size.height / 2;

    // Calculate starting position to align data to the right
    final dataLength = waveformData.length;
    final startIndex = (maxBars - dataLength).clamp(0, maxBars);

    // Draw inactive bars for empty positions (left side)
    for (int i = 0; i < startIndex; i++) {
      final x = i * barWidth + barWidth / 2;
      final barHeight = 0.1 * size.height; // Minimal height for empty bars
      final startY = centerY - barHeight / 2;
      final endY = centerY + barHeight / 2;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        inactivePaint,
      );
    }

    // Draw actual waveform data (right side, most recent)
    for (int i = 0; i < dataLength; i++) {
      final barIndex = startIndex + i;
      final x = barIndex * barWidth + barWidth / 2;
      final barHeight = waveformData[i] * size.height * 0.8; // Scale down slightly
      final startY = centerY - barHeight / 2;
      final endY = centerY + barHeight / 2;

      // Most recent bars (rightmost) are brighter
      final isRecent = i >= dataLength - 5; // Last 5 bars are "active"
      final currentPaint = isRecent ? activePaint : inactivePaint;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}