import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/global_toast.dart';
import '../data/dummy_data.dart';

class RecordingDetailScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const RecordingDetailScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  bool _isPlaying = false;
  double _currentPosition = 0.3; // 0.0 to 1.0
  late double _totalDuration;
  List<double> _waveformData = [];
  late Map<String, dynamic> _recordingData;
  
  // Search functionality
  bool _isSearching = false;
  String _searchQuery = '';
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Load recording data from centralized data
    _recordingData = DummyData.getRecordingDetail(widget.sessionId) ?? {};
    _totalDuration = (_recordingData['totalSeconds'] ?? 930).toDouble();
    
    _generateWaveformData();
  }

  void _generateWaveformData() {
    final random = math.Random();
    _waveformData = List.generate(100, (index) {
      return random.nextDouble() * 0.8 + 0.2; // 0.2 to 1.0
    });
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _enterSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _exitSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults.clear();
      _currentSearchIndex = -1;
      _searchController.clear();
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _searchResults.clear();
      _currentSearchIndex = -1;

      if (query.isNotEmpty) {
        // Search through actual recording transcripts
        final transcripts = _recordingData['transcripts'] as List<Map<String, dynamic>>? ?? [];

        for (int i = 0; i < transcripts.length; i++) {
          final text = (transcripts[i]['text']! as String).toLowerCase();
          if (text.contains(_searchQuery)) {
            _searchResults.add(i);
          }
        }

        if (_searchResults.isNotEmpty) {
          _currentSearchIndex = 0;
          _jumpToSearchResult(0);
        }
      }
    });
  }

  void _nextSearchResult() {
    if (_currentSearchIndex < _searchResults.length - 1) {
      setState(() {
        _currentSearchIndex++;
      });
      _jumpToSearchResult(_currentSearchIndex);
    }
  }

  void _previousSearchResult() {
    if (_currentSearchIndex > 0) {
      setState(() {
        _currentSearchIndex--;
      });
      _jumpToSearchResult(_currentSearchIndex);
    }
  }

  void _jumpToSearchResult(int resultIndex) {
    final textIndex = _searchResults[resultIndex];
    // This would scroll to the item and highlight it
    // For now, we'll just show a toast
    TOAST.sendMessage(MessageType.normal, 
      'Found at item ${textIndex + 1} (${resultIndex + 1}/${_searchResults.length})');
  }

  @override
  Widget build(BuildContext context) {
    // Get actual recording transcripts
    final transcripts = _recordingData['transcripts'] as List<Map<String, dynamic>>? ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search transcripts...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
              style: TextStyle(color: Colors.white),
              onChanged: _performSearch,
            )
          : Text('Recording Details'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_isSearching) ...[
            if (_searchResults.isNotEmpty) ...[
              IconButton(
                icon: Icon(Icons.keyboard_arrow_up),
                onPressed: _currentSearchIndex > 0 ? _previousSearchResult : null,
              ),
              IconButton(
                icon: Icon(Icons.keyboard_arrow_down),
                onPressed: _currentSearchIndex < _searchResults.length - 1 ? _nextSearchResult : null,
              ),
            ],
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _exitSearch,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _enterSearch,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                TOAST.sendMessage(MessageType.normal, 'Stage 2: Share feature (UI only)');
              },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                _showExportDialog(context);
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Recording info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sessionName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text('Total time: ${_recordingData['duration'] ?? 'N/A'}', style: TextStyle(color: Colors.white)),
                    SizedBox(width: 16),
                    Icon(Icons.text_fields, size: 16, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text('Texts: ${transcripts.length} items', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),

          // Audio player controls (temporary)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                    TOAST.sendMessage(MessageType.normal, 
                      _isPlaying ? 'Playing...' : 'Paused');
                  },
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Waveform with drag capability
                      GestureDetector(
                        onTapDown: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localPosition = box.globalToLocal(details.globalPosition);
                          final relativePosition = (localPosition.dx - 16 - 48 - 16) / (MediaQuery.of(context).size.width - 16 - 48 - 16 - 16);
                          setState(() {
                            _currentPosition = relativePosition.clamp(0.0, 1.0);
                          });
                          TOAST.sendMessage(MessageType.normal, 
                            'Seek to ${_formatDuration(_currentPosition * _totalDuration)}');
                        },
                        onPanUpdate: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localPosition = box.globalToLocal(details.globalPosition);
                          final relativePosition = (localPosition.dx - 16 - 48 - 16) / (MediaQuery.of(context).size.width - 16 - 48 - 16 - 16);
                          setState(() {
                            _currentPosition = relativePosition.clamp(0.0, 1.0);
                          });
                        },
                        child: Container(
                          height: 40,
                          child: CustomPaint(
                            painter: PlaybackWaveformPainter(
                              waveformData: _waveformData,
                              progress: _currentPosition,
                              isPlaying: _isPlaying,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_currentPosition * _totalDuration), 
                            style: TextStyle(fontSize: 12, color: Colors.white)),
                          Text(_formatDuration(_totalDuration), 
                            style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey[700]),

          // STT text list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: transcripts.length,
              itemBuilder: (context, index) {
                final textData = transcripts[index];
                return GestureDetector(
                  onTap: () {
                    // Use seconds from data object - whole card clickable
                    final seconds = textData['seconds'] as int;
                    final timestamp = textData['timestamp']! as String;
                    
                    setState(() {
                      _currentPosition = seconds / _totalDuration;
                    });
                  },
                  child: Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.only(bottom: 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Time badge on top left
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              textData['timestamp']! as String,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Text in the middle, expanded
                          Expanded(
                            child: Text(
                              textData['text']! as String,
                              style: const TextStyle(
                                fontSize: 13, 
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ),
                          // Copy button on the right - prevent propagation
                          _CopyButton(
                            onTap: () {
                              // Stop propagation - only copy
                              TOAST.sendMessage(MessageType.normal, 'Stage 2: Copy feature (UI only)');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Export', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet, color: Colors.grey),
              title: const Text('Text file (.txt)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                TOAST.sendMessage(MessageType.indicator, 'Stage 2: TXT export (UI only)');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.grey),
              title: const Text('CSV file (.csv)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                TOAST.sendMessage(MessageType.indicator, 'Stage 2: CSV export (UI only)');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Playback waveform painter that extends the original functionality
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
      final barHeight = waveformData[i] * size.height * 0.8;
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

// Copy button with touch feedback and larger touch area
class _CopyButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CopyButton({required this.onTap});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isPressed ? Colors.grey.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(Icons.copy, size: 14, color: Colors.grey),
        ),
      ),
    );
  }
}