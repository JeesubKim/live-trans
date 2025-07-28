import 'package:flutter/material.dart';

enum WaveformMode {
  recording, // Live recording mode (scrolling bars)
  playback,  // Playback mode (progress bar)
}

class AudioWaveformComponent extends StatelessWidget {
  // Common properties
  final List<double> waveformData;
  final bool isPaused;
  
  // Recording mode properties
  final Duration? recordingDuration;
  final int? maxWaveformBars;
  
  // Playback mode properties
  final double? progress; // 0.0 to 1.0
  final bool? isPlaying;
  final Function(double)? onSeek; // Callback for drag interactions
  
  // Mode
  final WaveformMode mode;

  // Recording mode constructor
  const AudioWaveformComponent.recording({
    super.key,
    required this.recordingDuration,
    required this.waveformData,
    required this.maxWaveformBars,
    required this.isPaused,
  }) : mode = WaveformMode.recording,
       progress = null,
       isPlaying = null,
       onSeek = null;

  // Playback mode constructor
  const AudioWaveformComponent.playback({
    super.key,
    required this.waveformData,
    required this.progress,
    required this.isPlaying,
    this.onSeek,
    this.isPaused = false,
  }) : mode = WaveformMode.playback,
       recordingDuration = null,
       maxWaveformBars = null;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case WaveformMode.recording:
        return _buildRecordingMode();
      case WaveformMode.playback:
        return _buildPlaybackMode(context);
    }
  }

  Widget _buildRecordingMode() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDuration(recordingDuration!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Waveform (flatter and wider)
          Expanded(
            child: SizedBox(
              height: 14, // Reduced from 20 to make it flatter
              child: CustomPaint(
                painter: RecordingWaveformPainter(
                  waveformData: waveformData,
                  maxBars: maxWaveformBars!,
                  isPaused: isPaused,
                ),
                size: const Size.fromHeight(60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackMode(BuildContext context) {
    Widget waveformWidget = SizedBox(
      height: 40,
      child: CustomPaint(
        painter: PlaybackWaveformPainter(
          waveformData: waveformData,
          progress: progress!,
          isPlaying: isPlaying!,
        ),
        size: Size.infinite,
      ),
    );

    // If onSeek is provided, wrap with GestureDetector for drag interactions
    if (onSeek != null) {
      waveformWidget = GestureDetector(
        onTapDown: (details) => _handleSeek(context, details.localPosition),
        onPanUpdate: (details) => _handleSeek(context, details.localPosition),
        child: waveformWidget,
      );
    }

    return waveformWidget;
  }

  void _handleSeek(BuildContext context, Offset localPosition) {
    if (onSeek == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final relativePosition = (localPosition.dx / size.width).clamp(0.0, 1.0);
    onSeek!(relativePosition);
  }
}

// Recording mode: Waveform painter with real-time scrolling effect
class RecordingWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final int maxBars;
  final bool isPaused;

  RecordingWaveformPainter({
    required this.waveformData,
    required this.maxBars,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final activePaint = Paint()
      ..color = isPaused ? Colors.grey.withOpacity(0.4) : Colors.blue
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / maxBars;
    final centerY = size.height / 2;

    // Calculate starting position to align data to the right
    final dataLength = waveformData.length;
    final startIndex = (maxBars - dataLength).clamp(0, maxBars);

    // Draw inactive bars for empty positions (left side)
    for (int i = 0; i < startIndex; i++) {
      final x = i * barWidth + barWidth / 2;
      const barHeight = 1.0; // Very small baseline for empty positions
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
      
      // Use input data as-is, no manipulation
      final amplitude = waveformData[i];
      final rawHeight = amplitude * size.height * 0.8;
      final barHeight = rawHeight < 0.5 ? 0.5 : rawHeight.clamp(0.5, size.height * 0.9);
      
      final startY = centerY - barHeight / 2;
      final endY = centerY + barHeight / 2;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(RecordingWaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
           oldDelegate.isPaused != isPaused;
  }
}

// Playback mode: Waveform painter with progress and drag capability
class PlaybackWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress; // 0.0 to 1.0
  final bool isPlaying;

  PlaybackWaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final playedPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final unplayedPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final progressLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;

    final barWidth = size.width / waveformData.length;
    final centerY = size.height / 2;
    final progressX = progress * size.width;

    // Draw waveform bars
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth + barWidth / 2;
      
      // Use input data as-is, no manipulation
      final amplitude = waveformData[i];
      final rawHeight = amplitude * size.height * 0.8;
      final barHeight = rawHeight < 0.5 ? 0.5 : rawHeight.clamp(0.5, size.height * 0.9);
      
      final startY = centerY - barHeight / 2;
      final endY = centerY + barHeight / 2;

      // Use played color if before progress line, unplayed color if after
      final paint = x <= progressX ? playedPaint : unplayedPaint;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        paint,
      );
    }

    // Draw progress line
    canvas.drawLine(
      Offset(progressX, 0),
      Offset(progressX, size.height),
      progressLinePaint,
    );
  }

  @override
  bool shouldRepaint(PlaybackWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.isPlaying != isPlaying ||
           oldDelegate.waveformData != waveformData;
  }
}