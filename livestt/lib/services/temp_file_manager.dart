import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'async_file_queue.dart';
import 'subtitle_display_manager.dart';
import 'subtitle_file_manager.dart';
import '../utils/debug_logger.dart';

/// Temporary session data structure
class TempSession {
  final String sessionId;
  final String tempFilePath;
  final DateTime startTime;
  final List<SubtitleItem> memoryBuffer; // For quick access
  
  TempSession({
    required this.sessionId,
    required this.tempFilePath,
    required this.startTime,
  }) : memoryBuffer = <SubtitleItem>[];
}

/// Temporary file manager for auto-saving during recording
/// Provides crash-safe recording with real-time backup
class TempFileManager {

  AsyncFileQueue? _fileQueue;
  TempSession? _currentSession;
  bool _isInitialized = false;

  /// Initialize temp file manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    DebugLogger.info('🔄 Initializing TempFileManager...');
    
    // Create and initialize new async file queue
    _fileQueue = AsyncFileQueue();
    await _fileQueue!.initialize();
    
    // Clean up any leftover temp files from previous crashes
    await _cleanupLeftoverTempFiles();
    
    _isInitialized = true;
    DebugLogger.info('✅ TempFileManager initialized');
  }

  /// Get temp directory
  Future<Directory> get _tempDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final tempDir = Directory(path.join(docs.path, 'temp_subtitles'));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  /// Start a new recording session
  Future<String> startSession() async {
    if (!_isInitialized || _fileQueue == null) {
      throw StateError('TempFileManager not initialized');
    }

    // Generate unique session ID
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final tempDir = await _tempDirectory;
    final tempFilePath = path.join(tempDir.path, '$sessionId.temp');

    // Create new session
    _currentSession = TempSession(
      sessionId: sessionId,
      tempFilePath: tempFilePath,
      startTime: DateTime.now(),
    );

    // Initialize temp file with session header as first line
    final sessionHeader = {
      'sessionId': sessionId,
      'startTime': DateTime.now().toIso8601String(),
      'version': '1.0',
      'type': 'session_header',
    };

    // Write session header as first JSON line
    await _fileQueue!.writeToFile(
      tempFilePath, 
      '${jsonEncode(sessionHeader)}\n'
    );

    DebugLogger.info('🚀 Recording session started: $sessionId');
    DebugLogger.info('📁 Temp file: $tempFilePath');
    
    return sessionId;
  }

  /// Add subtitle to current session (real-time auto-save)
  Future<void> addSubtitle(SubtitleItem subtitle) async {
    if (_currentSession == null) {
      DebugLogger.warning('No active session for subtitle save');
      return;
    }

    try {
      // Add to memory buffer for quick access
      _currentSession!.memoryBuffer.add(subtitle);

      // Create subtitle entry for append
      final subtitleJson = {
        'id': subtitle.id,
        'text': subtitle.text,
        'timestamp': subtitle.timestamp.toIso8601String(),
        'confidence': subtitle.confidence,
        'isComplete': subtitle.isComplete,
        'isConfirmed': subtitle.isConfirmed,
      };

      // Append to temp file (non-blocking)
      // We append as individual JSON objects separated by newlines for easy parsing
      final jsonLine = '${jsonEncode(subtitleJson)}\n';
      await _fileQueue!.appendToFile(_currentSession!.tempFilePath, jsonLine);

      DebugLogger.log('💾 Subtitle auto-saved: "${subtitle.text}" (${subtitle.id})');
    } catch (e) {
      DebugLogger.error('❌ Failed to auto-save subtitle: $e');
    }
  }

  /// Finalize session - convert temp file to permanent file
  Future<String?> finalizeSession({
    required String title,
    required String category,
    required String language,
    required String model,
    Duration? duration,
  }) async {
    if (_currentSession == null) {
      DebugLogger.warning('No active session to finalize');
      return null;
    }

    try {
      final session = _currentSession!;
      
      // Read all subtitle data from temp file for final compilation
      final tempFile = File(session.tempFilePath);
      if (!await tempFile.exists()) {
        DebugLogger.error('Temp file not found: ${session.tempFilePath}');
        return null;
      }

      // Parse subtitle data from temp file (JSON Lines format)
      final List<SubtitleItem> finalSubtitles = [];
      final lines = await tempFile.readAsLines();
      
      DebugLogger.info('📄 Parsing temp file with ${lines.length} lines');
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          
          // Skip session header
          if (json['type'] == 'session_header') {
            DebugLogger.info('📋 Skipping session header line $i');
            continue;
          }
          
          final subtitle = SubtitleItem(
            id: json['id'],
            text: json['text'] ?? '',
            timestamp: DateTime.parse(json['timestamp']),
            confidence: (json['confidence'] ?? 1.0).toDouble(),
            isComplete: json['isComplete'] ?? true,
            isConfirmed: json['isConfirmed'] ?? true,
          );
          
          finalSubtitles.add(subtitle);
          DebugLogger.info('📝 Parsed subtitle ${finalSubtitles.length}: "${subtitle.text}"');
        } catch (e) {
          DebugLogger.error('Error parsing subtitle line $i: $e');
          DebugLogger.error('Problematic line: ${line.length > 100 ? line.substring(0, 100) + "..." : line}');
          continue;
        }
      }
      
      DebugLogger.info('🔢 Total parsed subtitles: ${finalSubtitles.length}');

      if (finalSubtitles.isEmpty) {
        DebugLogger.warning('No subtitles found in session');
        await _discardSession(); // Clean up empty session
        return null;
      }

      // Create final subtitle file using existing SubtitleFileManager
      final subtitleFileManager = SubtitleFileManager();
      final finalFilePath = await subtitleFileManager.saveSubtitleFile(
        title: title,
        category: category,
        language: language,
        model: model,
        subtitles: finalSubtitles,
        duration: duration,
      );

      // Clean up temp file
      await _fileQueue!.deleteFile(session.tempFilePath);
      
      _currentSession = null;
      
      DebugLogger.info('✅ Session finalized: ${finalSubtitles.length} subtitles saved');
      DebugLogger.info('📁 Final file: $finalFilePath');
      
      return finalFilePath;
    } catch (e) {
      DebugLogger.error('❌ Failed to finalize session: $e');
      return null;
    }
  }

  /// Discard current session - delete temp file
  Future<void> discardSession() async {
    await _discardSession();
  }

  Future<void> _discardSession() async {
    if (_currentSession == null) {
      DebugLogger.warning('No active session to discard');
      return;
    }

    try {
      final session = _currentSession!;
      
      // Delete temp file
      await _fileQueue!.deleteFile(session.tempFilePath);
      
      _currentSession = null;
      
      DebugLogger.info('🗑️ Session discarded: ${session.sessionId}');
    } catch (e) {
      DebugLogger.error('❌ Failed to discard session: $e');
    }
  }

  /// Get current session info
  Map<String, dynamic>? getCurrentSessionInfo() {
    if (_currentSession == null) return null;

    final session = _currentSession!;
    return {
      'sessionId': session.sessionId,
      'startTime': session.startTime.toIso8601String(),
      'tempFilePath': session.tempFilePath,
      'subtitleCount': session.memoryBuffer.length,
      'duration': DateTime.now().difference(session.startTime).inSeconds,
    };
  }

  /// Clean up leftover temp files from crashes
  Future<void> _cleanupLeftoverTempFiles() async {
    try {
      final tempDir = await _tempDirectory;
      if (!await tempDir.exists()) return;

      final tempFiles = await tempDir.list().where((entity) {
        return entity is File && entity.path.endsWith('.temp');
      }).toList();

      if (tempFiles.isNotEmpty) {
        DebugLogger.info('🧹 Cleaning up ${tempFiles.length} leftover temp files...');
        
        for (final file in tempFiles) {
          try {
            await file.delete();
            DebugLogger.log('🗑️ Deleted leftover temp file: ${file.path}');
          } catch (e) {
            DebugLogger.error('Failed to delete temp file: $e');
          }
        }
        
        DebugLogger.info('✅ Temp file cleanup completed');
      }
    } catch (e) {
      DebugLogger.error('Error during temp file cleanup: $e');
    }
  }

  /// Get recovery info from leftover temp files (for crash recovery)
  Future<List<Map<String, dynamic>>> getRecoveryInfo() async {
    try {
      final tempDir = await _tempDirectory;
      if (!await tempDir.exists()) return [];

      final tempFiles = await tempDir.list().where((entity) {
        return entity is File && entity.path.endsWith('.temp');
      }).toList();

      final recoveryInfo = <Map<String, dynamic>>[];
      
      for (final file in tempFiles) {
        try {
          final content = await (file as File).readAsString();
          final lines = content.split('\n');
          
          if (lines.isNotEmpty) {
            final firstLine = lines.first.trim();
            if (firstLine.isNotEmpty) {
              final sessionData = jsonDecode(firstLine) as Map<String, dynamic>;
              
              final subtitleCount = lines.where((line) => 
                line.trim().isNotEmpty && !line.contains('"type":"session_header"')).length;
              
              recoveryInfo.add({
                'sessionId': sessionData['sessionId'],
                'startTime': sessionData['startTime'],
                'filePath': file.path,
                'subtitleCount': subtitleCount,
                'fileSize': await file.length(),
              });
            }
          }
        } catch (e) {
          DebugLogger.error('Error reading temp file for recovery: $e');
        }
      }
      
      return recoveryInfo;
    } catch (e) {
      DebugLogger.error('Error getting recovery info: $e');
      return [];
    }
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final tempDir = await _tempDirectory;
      final currentSessionInfo = getCurrentSessionInfo();
      final queueStats = _fileQueue?.getQueueStats() ?? {};
      
      return {
        'tempDirectory': tempDir.path,
        'currentSession': currentSessionInfo,
        'fileQueue': queueStats,
        'isInitialized': _isInitialized,
      };
    } catch (e) {
      DebugLogger.error('Error getting storage stats: $e');
      return {};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    DebugLogger.info('🗑️ Disposing TempFileManager...');
    
    // Discard current session if active
    if (_currentSession != null) {
      await _discardSession();
    }
    
    // Dispose file queue
    if (_fileQueue != null) {
      await _fileQueue!.dispose();
      _fileQueue = null;
    }
    
    _isInitialized = false;
    DebugLogger.info('✅ TempFileManager disposed');
  }
}