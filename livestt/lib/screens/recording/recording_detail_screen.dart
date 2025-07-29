import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../utils/global_toast.dart';
import '../../services/subtitle_file_manager.dart';
import '../../services/subtitle_display_manager.dart';
import '../../components/audio_waveform_component.dart';

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
  double _currentPosition = 0.0; // 0.0 to 1.0
  late double _totalDuration;
  List<double> _waveformData = [];
  SubtitleFile? _subtitleFile;
  final SubtitleFileManager _fileManager = SubtitleFileManager();
  
  // Search functionality
  bool _isSearching = false;
  String _searchQuery = '';
  List<Map<String, int>> _searchResults = []; // {textIndex, matchIndex}
  int _currentSearchIndex = -1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecordingData();
    _generateWaveformData();
  }

  Future<void> _loadRecordingData() async {
    try {
      final subtitleFile = await _fileManager.loadSubtitleFile(widget.sessionId);
      setState(() {
        _subtitleFile = subtitleFile;
        _totalDuration = (subtitleFile.metadata.duration?.inSeconds ?? 930).toDouble();
      });
    } catch (e) {
      print('Error loading subtitle file: $e');
      setState(() {
        _subtitleFile = null;
        _totalDuration = 930.0;
      });
    }
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
  
  String _formatTimestamp(DateTime timestamp) {
    // timestamp is relative to epoch, so we can use it directly for elapsed time
    final totalSeconds = timestamp.millisecondsSinceEpoch ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Helper function to check if current playback time matches this text item
  bool _isCurrentlyPlaying(int textIndex, List<SubtitleItem> subtitles) {
    if (textIndex >= subtitles.length) return false;
    
    final currentSeconds = _currentPosition * _totalDuration;
    final currentTextSeconds = subtitles[textIndex].timestamp.millisecondsSinceEpoch / 1000.0;
    
    // Check if current time falls within this text item's range
    // If it's the last item, it's current if playback time >= its start time
    if (textIndex == subtitles.length - 1) {
      return currentSeconds >= currentTextSeconds;
    }
    
    // For other items, check if current time is between this item and the next
    final nextTextSeconds = subtitles[textIndex + 1].timestamp.millisecondsSinceEpoch / 1000.0;
    return currentSeconds >= currentTextSeconds && currentSeconds < nextTextSeconds;
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

      if (query.isNotEmpty && _subtitleFile != null) {
        // Search through subtitle items
        final subtitles = _subtitleFile!.subtitles;

        for (int textIndex = 0; textIndex < subtitles.length; textIndex++) {
          final text = subtitles[textIndex].text.toLowerCase();
          
          // Find all matches in this text
          int start = 0;
          int matchIndex = 0;
          while (start < text.length) {
            final index = text.indexOf(_searchQuery, start);
            if (index == -1) break;
            
            _searchResults.add({
              'textIndex': textIndex,
              'matchIndex': matchIndex,
            });
            
            start = index + _searchQuery.length;
            matchIndex++;
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
    final searchResult = _searchResults[resultIndex];
    // final textIndex = searchResult['textIndex']!; // Unused
    // final matchIndex = searchResult['matchIndex']!; // Unused
    // This would scroll to the item and highlight it
    // Toast removed per user request
  }

  // Helper function to build highlighted text
  Widget _buildHighlightedText(String text, int textIndex) {
    if (_searchQuery.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 13, 
          color: Colors.white,
          height: 1.2,
        ),
      );
    }

    // Check if this text has any matches
    final hasMatches = _searchResults.any((result) => result['textIndex'] == textIndex);
    
    if (!hasMatches) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 13, 
          color: Colors.white,
          height: 1.2,
        ),
      );
    }

    // Get current match info
    final currentMatch = _searchResults.isNotEmpty && _currentSearchIndex >= 0 
        ? _searchResults[_currentSearchIndex] 
        : null;
    final currentTextIndex = currentMatch?['textIndex'];
    final currentMatchIndex = currentMatch?['matchIndex'];

    // Split text and highlight search matches
    final lowerText = text.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    
    List<TextSpan> spans = [];
    int start = 0;
    int matchIndex = 0;
    
    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // No more matches, add remaining text
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.2),
        ));
        break;
      }
      
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.2),
        ));
      }
      
      // Check if this is the current match
      final isCurrentMatch = currentTextIndex == textIndex && currentMatchIndex == matchIndex;
      
      // Add highlighted match (preserve original case)
      spans.add(TextSpan(
        text: text.substring(index, index + _searchQuery.length),
        style: TextStyle(
          fontSize: 13,
          color: Colors.black,
          height: 1.2,
          backgroundColor: isCurrentMatch ? Colors.orange : Colors.grey.withOpacity(0.5),
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + lowerQuery.length;
      matchIndex++;
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get subtitle items
    final subtitles = _subtitleFile?.subtitles ?? [];

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
              // Search result counter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Text(
                    '${_currentSearchIndex + 1}/${_searchResults.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
                toast.sendMessage(MessageType.normal, 'Stage 2: Share feature (UI only)');
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
                    Text('Total time: ${_formatDuration(_totalDuration)}', style: TextStyle(color: Colors.white)),
                    SizedBox(width: 16),
                    Icon(Icons.text_fields, size: 16, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text('Texts: ${subtitles.length} items', style: TextStyle(color: Colors.white)),
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
                    toast.sendMessage(MessageType.normal, 
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
                      AudioWaveformComponent.playback(
                        waveformData: _waveformData,
                        progress: _currentPosition,
                        isPlaying: _isPlaying,
                        onSeek: (position) {
                          setState(() {
                            _currentPosition = position;
                          });
                        },
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
              itemCount: subtitles.length,
              itemBuilder: (context, index) {
                final subtitle = subtitles[index];
                return GestureDetector(
                  onTap: () {
                    // Use timestamp from subtitle item
                    final seconds = subtitle.timestamp.millisecondsSinceEpoch / 1000.0;
                    
                    setState(() {
                      _currentPosition = seconds / _totalDuration;
                    });
                  },
                  child: Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.only(bottom: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      side: _isCurrentlyPlaying(index, subtitles)
                          ? BorderSide(color: Colors.white, width: 2.0)
                          : BorderSide.none,
                    ),
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
                              _formatTimestamp(subtitle.timestamp),
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
                            child: _buildHighlightedText(subtitle.text, index),
                          ),
                          // Copy button on the right - prevent propagation
                          _CopyButton(
                            onTap: () {
                              // Stop propagation - only copy
                              toast.sendMessage(MessageType.normal, 'Stage 2: Copy feature (UI only)');
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
              onTap: () async {
                Navigator.pop(context);
                await _exportToFormat('txt');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.grey),
              title: const Text('CSV file (.csv)', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await _exportToFormat('csv');
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

  Future<void> _exportToFormat(String format) async {
    // TODO: Implement export functionality for new subtitle format
    globalToast.warning('Export feature coming soon for new format');
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