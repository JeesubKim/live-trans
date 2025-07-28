import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/debug_logger.dart';

class AudioFileInfo {
  final String filePath;
  final String fileName;
  final DateTime timestamp;
  final int fileSizeBytes;
  final Duration duration;
  final String format;

  AudioFileInfo({
    required this.filePath,
    required this.fileName,
    required this.timestamp,
    required this.fileSizeBytes,
    required this.duration,
    this.format = 'wav',
  });

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'timestamp': timestamp.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'durationMs': duration.inMilliseconds,
      'format': format,
    };
  }

  factory AudioFileInfo.fromJson(Map<String, dynamic> json) {
    return AudioFileInfo(
      filePath: json['filePath'],
      fileName: json['fileName'],
      timestamp: DateTime.parse(json['timestamp']),
      fileSizeBytes: json['fileSizeBytes'],
      duration: Duration(milliseconds: json['durationMs']),
      format: json['format'] ?? 'wav',
    );
  }
}

class AudioFileService {
  static final AudioFileService _instance = AudioFileService._internal();
  factory AudioFileService() => _instance;
  AudioFileService._internal();

  String? _audioDirectory;
  final List<AudioFileInfo> _audioFiles = [];

  List<AudioFileInfo> get audioFiles => List.unmodifiable(_audioFiles);

  // Initialize service and create audio directory
  Future<bool> initialize() async {
    try {
      DebugLogger.info('🎵 Initializing AudioFileService...');
      
      // Get documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      _audioDirectory = path.join(documentsDir.path, 'audio_recordings');
      
      // Create directory if it doesn't exist
      final dir = Directory(_audioDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        DebugLogger.info('📁 Created audio directory: $_audioDirectory');
      }

      // Load existing audio files
      await _loadExistingFiles();
      
      DebugLogger.info('✅ AudioFileService initialized successfully');
      DebugLogger.info('📂 Audio directory: $_audioDirectory');
      DebugLogger.info('🎵 Found ${_audioFiles.length} existing audio files');
      
      return true;
    } catch (e) {
      DebugLogger.error('❌ Error initializing AudioFileService: $e');
      return false;
    }
  }

  // Save audio file with subtitle correlation
  Future<AudioFileInfo?> saveAudioFile({
    required String originalFilePath,
    String? customFileName,
    String? subtitleId,
  }) async {
    if (_audioDirectory == null) {
      DebugLogger.error('❌ AudioFileService not initialized');
      return null;
    }

    try {
      final originalFile = File(originalFilePath);
      if (!await originalFile.exists()) {
        DebugLogger.error('❌ Original audio file not found: $originalFilePath');
        return null;
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now();
      final fileName = customFileName ?? 
          'recording_${timestamp.millisecondsSinceEpoch}.wav';
      
      final newFilePath = path.join(_audioDirectory!, fileName);
      
      // Copy file to audio directory
      final newFile = await originalFile.copy(newFilePath);
      
      // Get file info
      final fileStats = await newFile.stat();
      final fileSize = fileStats.size;
      
      // Estimate duration (rough calculation for WAV files)
      // For 16kHz, 16-bit WAV: bytes / (sample_rate * 2) seconds
      final estimatedDuration = Duration(
        milliseconds: ((fileSize / (16000 * 2)) * 1000).round(),
      );

      final audioInfo = AudioFileInfo(
        filePath: newFilePath,
        fileName: fileName,
        timestamp: timestamp,
        fileSizeBytes: fileSize,
        duration: estimatedDuration,
        format: 'wav',
      );

      // Add to list
      _audioFiles.insert(0, audioInfo); // Most recent first
      
      // Save metadata if subtitle ID provided
      if (subtitleId != null) {
        await _saveAudioSubtitleLink(audioInfo, subtitleId);
      }

      DebugLogger.info('💾 Audio file saved: $fileName');
      DebugLogger.info('📊 Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      DebugLogger.info('⏱️ Duration: ${estimatedDuration.inSeconds}s');
      
      return audioInfo;
    } catch (e) {
      DebugLogger.error('❌ Error saving audio file: $e');
      return null;
    }
  }

  // Delete audio file
  Future<bool> deleteAudioFile(AudioFileInfo audioInfo) async {
    try {
      final file = File(audioInfo.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from list
      _audioFiles.removeWhere((info) => info.filePath == audioInfo.filePath);
      
      // Delete associated metadata
      await _deleteAudioSubtitleLink(audioInfo);
      
      DebugLogger.info('🗑️ Audio file deleted: ${audioInfo.fileName}');
      return true;
    } catch (e) {
      DebugLogger.error('❌ Error deleting audio file: $e');
      return false;
    }
  }

  // Get audio files by date range
  List<AudioFileInfo> getAudioFilesByDateRange(DateTime start, DateTime end) {
    return _audioFiles.where((info) => 
      info.timestamp.isAfter(start) && info.timestamp.isBefore(end)
    ).toList();
  }

  // Get audio files by size range
  List<AudioFileInfo> getAudioFilesBySize({int? minBytes, int? maxBytes}) {
    return _audioFiles.where((info) {
      if (minBytes != null && info.fileSizeBytes < minBytes) return false;
      if (maxBytes != null && info.fileSizeBytes > maxBytes) return false;
      return true;
    }).toList();
  }

  // Get total storage used
  int getTotalStorageUsed() {
    return _audioFiles.fold<int>(0, (sum, info) => sum + info.fileSizeBytes);
  }

  // Clean up old files (keep only recent N files)
  Future<void> cleanupOldFiles({int keepRecentCount = 10}) async {
    if (_audioFiles.length <= keepRecentCount) return;

    try {
      // Sort by timestamp (newest first)
      _audioFiles.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Delete files beyond keep count
      final filesToDelete = _audioFiles.skip(keepRecentCount).toList();
      
      for (final fileInfo in filesToDelete) {
        await deleteAudioFile(fileInfo);
      }
      
      DebugLogger.info('🧹 Cleaned up ${filesToDelete.length} old audio files');
    } catch (e) {
      DebugLogger.error('❌ Error cleaning up old files: $e');
    }
  }

  // Load existing audio files from directory
  Future<void> _loadExistingFiles() async {
    if (_audioDirectory == null) return;

    try {
      final dir = Directory(_audioDirectory!);
      if (!await dir.exists()) return;

      final files = await dir.list().toList();
      _audioFiles.clear();

      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.wav')) {
          try {
            final fileName = path.basename(entity.path);
            final stats = await entity.stat();
            
            // Extract timestamp from filename if possible
            DateTime timestamp;
            final timestampMatch = RegExp(r'recording_(\d+)\.wav').firstMatch(fileName);
            if (timestampMatch != null) {
              timestamp = DateTime.fromMillisecondsSinceEpoch(
                int.parse(timestampMatch.group(1)!)
              );
            } else {
              timestamp = stats.modified;
            }

            // Estimate duration
            final estimatedDuration = Duration(
              milliseconds: ((stats.size / (16000 * 2)) * 1000).round(),
            );

            final audioInfo = AudioFileInfo(
              filePath: entity.path,
              fileName: fileName,
              timestamp: timestamp,
              fileSizeBytes: stats.size,
              duration: estimatedDuration,
              format: 'wav',
            );

            _audioFiles.add(audioInfo);
          } catch (e) {
            DebugLogger.warning('⚠️ Error loading audio file ${entity.path}: $e');
          }
        }
      }

      // Sort by timestamp (newest first)
      _audioFiles.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
    } catch (e) {
      DebugLogger.error('❌ Error loading existing audio files: $e');
    }
  }

  // Save audio-subtitle link metadata
  Future<void> _saveAudioSubtitleLink(AudioFileInfo audioInfo, String subtitleId) async {
    try {
      final linkFile = File(path.join(_audioDirectory!, '${audioInfo.fileName}.link'));
      final linkData = {
        'audioFile': audioInfo.fileName,
        'subtitleId': subtitleId,
        'timestamp': audioInfo.timestamp.toIso8601String(),
      };
      
      await linkFile.writeAsString(linkData.toString());
    } catch (e) {
      DebugLogger.warning('⚠️ Error saving audio-subtitle link: $e');
    }
  }

  // Delete audio-subtitle link metadata
  Future<void> _deleteAudioSubtitleLink(AudioFileInfo audioInfo) async {
    try {
      final linkFile = File(path.join(_audioDirectory!, '${audioInfo.fileName}.link'));
      if (await linkFile.exists()) {
        await linkFile.delete();
      }
    } catch (e) {
      DebugLogger.warning('⚠️ Error deleting audio-subtitle link: $e');
    }
  }

  // Get storage statistics
  Map<String, dynamic> getStorageStats() {
    final totalSize = getTotalStorageUsed();
    final fileCount = _audioFiles.length;
    final avgFileSize = fileCount > 0 ? totalSize ~/ fileCount : 0;
    
    return {
      'totalFiles': fileCount,
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'averageFileSizeBytes': avgFileSize,
      'averageFileSizeMB': (avgFileSize / 1024 / 1024).toStringAsFixed(2),
      'directory': _audioDirectory,
    };
  }

  // Export audio file info as JSON
  String exportAudioListAsJson() {
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalFiles': _audioFiles.length,
      'files': _audioFiles.map((info) => info.toJson()).toList(),
    };
    
    return data.toString();
  }

  // Dispose resources
  void dispose() {
    _audioFiles.clear();
    DebugLogger.info('🎵 AudioFileService disposed');
  }
}