import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/debug_logger.dart';

class RecordingFile {
  final String recordingId;
  final String recordingName;
  final String folderPath;
  final String audioPath;
  final String subtitlePath;
  final DateTime createdAt;
  final int duration; // in seconds
  final List<SubtitleEntry> subtitles;

  RecordingFile({
    required this.recordingId,
    required this.recordingName,
    required this.folderPath,
    required this.audioPath,
    required this.subtitlePath,
    required this.createdAt,
    required this.duration,
    required this.subtitles,
  });

  // Create RecordingFile from folder path
  static Future<RecordingFile?> fromFolder(String folderPath) async {
    try {
      final folder = Directory(folderPath);
      if (!await folder.exists()) return null;

      final recordingId = path.basename(folderPath);
      
      // Find audio file in the folder
      final audioFile = await _findAudioFile(folderPath, recordingId);
      if (audioFile == null) return null;

      // Find subtitle file
      final subtitlePath = path.join(folderPath, '$recordingId.subtitifile');
      final subtitleFile = File(subtitlePath);
      if (!await subtitleFile.exists()) return null;

      // Parse subtitle file
      final subtitles = await _parseSubtitleFile(subtitlePath);
      
      // Get creation time and duration
      final stat = await audioFile.stat();
      final duration = _calculateDuration(subtitles);

      return RecordingFile(
        recordingId: recordingId,
        recordingName: recordingId.replaceAll('_', ' '),
        folderPath: folderPath,
        audioPath: audioFile.path,
        subtitlePath: subtitlePath,
        createdAt: stat.modified,
        duration: duration,
        subtitles: subtitles,
      );
    } catch (e) {
      DebugLogger.error('Error loading recording from folder $folderPath: $e');
      return null;
    }
  }

  // Find audio file with supported extensions
  static Future<File?> _findAudioFile(String folderPath, String recordingId) async {
    final supportedExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];
    
    for (final ext in supportedExtensions) {
      final audioPath = path.join(folderPath, '$recordingId.$ext');
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        return audioFile;
      }
    }
    return null;
  }

  // Parse subtitle file
  static Future<List<SubtitleEntry>> _parseSubtitleFile(String subtitlePath) async {
    try {
      final file = File(subtitlePath);
      final lines = await file.readAsLines();
      
      final subtitles = <SubtitleEntry>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        final parts = line.split('\t');
        if (parts.length >= 2) {
          final timestamp = parts[0];
          final text = parts.sublist(1).join('\t'); // Handle text with tabs
          final seconds = _parseTimestamp(timestamp);
          
          subtitles.add(SubtitleEntry(
            timestamp: timestamp,
            seconds: seconds,
            text: text,
          ));
        }
      }
      
      return subtitles;
    } catch (e) {
      DebugLogger.error('Error parsing subtitle file $subtitlePath: $e');
      return [];
    }
  }

  // Parse timestamp to seconds
  static int _parseTimestamp(String timestamp) {
    try {
      final parts = timestamp.split(':');
      if (parts.length == 3) {
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return minutes * 60 + seconds;
      }
    } catch (e) {
      DebugLogger.error('Error parsing timestamp $timestamp: $e');
    }
    return 0;
  }

  // Calculate total duration from subtitles
  static int _calculateDuration(List<SubtitleEntry> subtitles) {
    if (subtitles.isEmpty) return 0;
    // Return the timestamp of the last subtitle + some buffer
    return subtitles.last.seconds + 30; // Add 30 seconds buffer
  }

  // Format duration as MM:SS
  String get formattedDuration {
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Get formatted date
  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  // Export to TXT format
  Future<String> exportToTxt() async {
    final buffer = StringBuffer();
    for (final subtitle in subtitles) {
      buffer.writeln(subtitle.text);
    }
    return buffer.toString();
  }

  // Export to CSV format
  Future<String> exportToCsv() async {
    final buffer = StringBuffer();
    for (final subtitle in subtitles) {
      buffer.writeln('${subtitle.timestamp}\t${subtitle.text}');
    }
    return buffer.toString();
  }
}

class SubtitleEntry {
  final String timestamp;
  final int seconds;
  final String text;

  SubtitleEntry({
    required this.timestamp,
    required this.seconds,
    required this.text,
  });

  // Convert to Map for compatibility with existing code
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'seconds': seconds,
      'text': text,
    };
  }
}