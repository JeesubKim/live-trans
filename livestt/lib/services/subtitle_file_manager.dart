import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'subtitle_display_manager.dart';
import '../utils/debug_logger.dart';

// Subtitle file metadata
class SubtitleFileMetadata {
  final String title;
  final String category;
  final String language;
  final String model;
  final DateTime created;
  final Duration? duration;
  final String? audioFilePath;

  SubtitleFileMetadata({
    required this.title,
    required this.category,
    required this.language,
    required this.model,
    required this.created,
    this.duration,
    this.audioFilePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'language': language,
      'model': model,
      'created': created.toIso8601String(),
      'duration': duration?.inSeconds,
      'audioFilePath': audioFilePath,
    };
  }

  factory SubtitleFileMetadata.fromJson(Map<String, dynamic> json) {
    return SubtitleFileMetadata(
      title: json['title'] ?? '',
      category: json['category'] ?? 'Other',
      language: json['language'] ?? 'Unknown',
      model: json['model'] ?? 'Unknown',
      created: DateTime.parse(json['created']),
      duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
      audioFilePath: json['audioFilePath'],
    );
  }
}

// Complete subtitle file structure
class SubtitleFile {
  final String version;
  final SubtitleFileMetadata metadata;
  final List<SubtitleItem> subtitles;

  SubtitleFile({
    this.version = '1.0',
    required this.metadata,
    required this.subtitles,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'metadata': metadata.toJson(),
      'subtitles': subtitles.map((item) => {
        'id': item.id,
        'text': item.text,
        'timestamp': item.timestamp.toIso8601String(),
        'confidence': item.confidence,
        'isComplete': item.isComplete,
        'isConfirmed': item.isConfirmed,
      }).toList(),
    };
  }

  factory SubtitleFile.fromJson(Map<String, dynamic> json) {
    final subtitlesJson = json['subtitles'] as List<dynamic>? ?? [];
    final subtitles = subtitlesJson.map((item) {
      return SubtitleItem(
        id: item['id'],
        text: item['text'] ?? '',
        timestamp: DateTime.parse(item['timestamp']),
        confidence: (item['confidence'] ?? 1.0).toDouble(),
        isComplete: item['isComplete'] ?? true,
        isConfirmed: item['isConfirmed'] ?? true,
      );
    }).toList();

    return SubtitleFile(
      version: json['version'] ?? '1.0',
      metadata: SubtitleFileMetadata.fromJson(json['metadata'] ?? {}),
      subtitles: subtitles,
    );
  }
}

// Subtitle file manager service
class SubtitleFileManager {
  static final SubtitleFileManager _instance = SubtitleFileManager._internal();
  factory SubtitleFileManager() => _instance;
  SubtitleFileManager._internal();

  // Get app documents directory
  Future<Directory> get _documentsDirectory async {
    return await getApplicationDocumentsDirectory();
  }

  // Get subtitles directory
  Future<Directory> get _subtitlesDirectory async {
    final docs = await _documentsDirectory;
    final subtitlesDir = Directory(path.join(docs.path, 'subtitles'));
    if (!await subtitlesDir.exists()) {
      await subtitlesDir.create(recursive: true);
    }
    return subtitlesDir;
  }

  // Generate safe filename from title
  String _sanitizeFilename(String title) {
    // Remove invalid characters and limit length
    String sanitized = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    
    // Limit length and ensure .subtitfile extension
    if (sanitized.length > 50) {
      sanitized = sanitized.substring(0, 50);
    }
    
    return '$sanitized.subtitfile';
  }

  // Save subtitle file
  Future<String> saveSubtitleFile({
    required String title,
    required String category,
    required String language,
    required String model,
    required List<SubtitleItem> subtitles,
    Duration? duration,
    String? audioFilePath,
  }) async {
    try {
      final subtitlesDir = await _subtitlesDirectory;
      final filename = _sanitizeFilename(title);
      final file = File(path.join(subtitlesDir.path, filename));

      // Create subtitle file structure
      final subtitleFile = SubtitleFile(
        metadata: SubtitleFileMetadata(
          title: title,
          category: category,
          language: language,
          model: model,
          created: DateTime.now(),
          duration: duration,
          audioFilePath: audioFilePath,
        ),
        subtitles: subtitles,
      );

      // Convert to JSON and save
      final jsonString = const JsonEncoder.withIndent('  ').convert(subtitleFile.toJson());
      await file.writeAsString(jsonString);

      DebugLogger.info('Subtitle file saved: ${file.path}');
      return file.path;
    } catch (e) {
      DebugLogger.error('Error saving subtitle file: $e');
      throw Exception('Failed to save subtitle file: $e');
    }
  }

  // Load subtitle file
  Future<SubtitleFile> loadSubtitleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Subtitle file not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      return SubtitleFile.fromJson(jsonData);
    } catch (e) {
      DebugLogger.error('Error loading subtitle file: $e');
      throw Exception('Failed to load subtitle file: $e');
    }
  }

  // List all subtitle files
  Future<List<FileSystemEntity>> listSubtitleFiles() async {
    try {
      final subtitlesDir = await _subtitlesDirectory;
      final files = await subtitlesDir.list().where((entity) {
        return entity is File && entity.path.endsWith('.subtitfile');
      }).toList();

      // Sort by modification date (newest first)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      return files;
    } catch (e) {
      DebugLogger.error('Error listing subtitle files: $e');
      return [];
    }
  }

  // Get file metadata without loading full content
  Future<SubtitleFileMetadata?> getFileMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final metadataJson = jsonData['metadata'] as Map<String, dynamic>?;
      if (metadataJson == null) return null;

      return SubtitleFileMetadata.fromJson(metadataJson);
    } catch (e) {
      DebugLogger.error('Error getting file metadata: $e');
      return null;
    }
  }

  // Delete subtitle file
  Future<bool> deleteSubtitleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        DebugLogger.info('Subtitle file deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      DebugLogger.error('Error deleting subtitle file: $e');
      return false;
    }
  }

  // Export subtitle file to different formats
  Future<String> exportToSRT(SubtitleFile subtitleFile, String outputPath) async {
    try {
      final file = File(outputPath);
      final buffer = StringBuffer();
      
      for (int i = 0; i < subtitleFile.subtitles.length; i++) {
        final subtitle = subtitleFile.subtitles[i];
        final startTime = _formatSRTTime(subtitle.timestamp);
        
        // Calculate end time (use next subtitle's timestamp or add 3 seconds)
        final endTime = i < subtitleFile.subtitles.length - 1
            ? _formatSRTTime(subtitleFile.subtitles[i + 1].timestamp)
            : _formatSRTTime(subtitle.timestamp.add(const Duration(seconds: 3)));
        
        buffer.writeln('${i + 1}');
        buffer.writeln('$startTime --> $endTime');
        buffer.writeln(subtitle.text);
        buffer.writeln();
      }
      
      await file.writeAsString(buffer.toString());
      return file.path;
    } catch (e) {
      DebugLogger.error('Error exporting to SRT: $e');
      throw Exception('Failed to export to SRT: $e');
    }
  }

  // Format time for SRT format (HH:MM:SS,mmm)
  String _formatSRTTime(DateTime dateTime) {
    final time = dateTime;
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    final seconds = time.second.toString().padLeft(2, '0');
    final milliseconds = time.millisecond.toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  // Get storage statistics
  Future<Map<String, dynamic>> getStorageStatistics() async {
    try {
      final subtitlesDir = await _subtitlesDirectory;
      final files = await listSubtitleFiles();
      
      int totalSize = 0;
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      
      return {
        'totalFiles': files.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
        'directory': subtitlesDir.path,
      };
    } catch (e) {
      DebugLogger.error('Error getting storage statistics: $e');
      return {
        'totalFiles': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': '0.00',
        'directory': 'Unknown',
      };
    }
  }
}