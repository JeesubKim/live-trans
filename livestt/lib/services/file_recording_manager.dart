import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/recording_file.dart';

class FileRecordingManager {
  static const String _recordingsFolder = 'recordings';
  
  // Get the recordings directory path
  static String get recordingsPath {
    // For development/testing, use absolute path
    // In production, this should use app documents directory
    return 'D:\\Proj\\live-trans\\livestt\\recordings';
  }

  // Load all recordings from the recordings folder
  static Future<List<RecordingFile>> loadAllRecordings() async {
    try {
      final recordingsDir = Directory(recordingsPath);
      
      if (!await recordingsDir.exists()) {
        return [];
      }

      final recordings = <RecordingFile>[];
      
      // List all subdirectories in recordings folder
      await for (final entity in recordingsDir.list()) {
        if (entity is Directory) {
          final recording = await RecordingFile.fromFolder(entity.path);
          if (recording != null) {
            recordings.add(recording);
          }
        }
      }
      
      // Sort by creation date (newest first)
      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return recordings;
    } catch (e) {
      return [];
    }
  }

  // Load a specific recording by ID
  static Future<RecordingFile?> loadRecording(String recordingId) async {
    try {
      final folderPath = path.join(recordingsPath, recordingId);
      return await RecordingFile.fromFolder(folderPath);
    } catch (e) {
      print('Error loading recording $recordingId: $e');
      return null;
    }
  }

  // Get recordings list for RecordingsScreen (summary format)
  static Future<List<Map<String, dynamic>>> getRecordingsList() async {
    final recordings = await loadAllRecordings();
    
    return recordings.map((recording) {
      return {
        'id': recording.recordingId,
        'name': recording.recordingName,
        'duration': recording.formattedDuration,
        'date': recording.formattedDate,
        'textCount': recording.subtitles.length,
      };
    }).toList();
  }

  // Get recording detail for RecordingDetailScreen
  static Future<Map<String, dynamic>?> getRecordingDetail(String sessionId) async {
    final recording = await loadRecording(sessionId);
    if (recording == null) return null;

    return {
      'id': recording.recordingId,
      'name': recording.recordingName,
      'duration': recording.formattedDuration,
      'totalSeconds': recording.duration,
      'transcripts': recording.subtitles.map((subtitle) => subtitle.toMap()).toList(),
    };
  }

  // Save a new recording (for future STT implementation)
  static Future<bool> saveRecording({
    required String recordingId,
    required String audioFilePath,
    required List<SubtitleEntry> subtitles,
  }) async {
    try {
      // Create recording folder
      final folderPath = path.join(recordingsPath, recordingId);
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      // Copy audio file to recording folder
      final audioFile = File(audioFilePath);
      final audioExtension = path.extension(audioFilePath);
      final targetAudioPath = path.join(folderPath, '$recordingId$audioExtension');
      await audioFile.copy(targetAudioPath);

      // Save subtitle file
      final subtitlePath = path.join(folderPath, '$recordingId.subtitifile');
      final subtitleFile = File(subtitlePath);
      
      final buffer = StringBuffer();
      for (final subtitle in subtitles) {
        buffer.writeln('${subtitle.timestamp}\t${subtitle.text}');
      }
      
      await subtitleFile.writeAsString(buffer.toString());

      return true;
    } catch (e) {
      print('Error saving recording $recordingId: $e');
      return false;
    }
  }

  // Delete a recording
  static Future<bool> deleteRecording(String recordingId) async {
    try {
      final folderPath = path.join(recordingsPath, recordingId);
      final folder = Directory(folderPath);
      
      if (await folder.exists()) {
        await folder.delete(recursive: true);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error deleting recording $recordingId: $e');
      return false;
    }
  }

  // Export recording to TXT
  static Future<String?> exportToTxt(String recordingId) async {
    try {
      final recording = await loadRecording(recordingId);
      if (recording == null) return null;
      
      return await recording.exportToTxt();
    } catch (e) {
      print('Error exporting recording $recordingId to TXT: $e');
      return null;
    }
  }

  // Export recording to CSV
  static Future<String?> exportToCsv(String recordingId) async {
    try {
      final recording = await loadRecording(recordingId);
      if (recording == null) return null;
      
      return await recording.exportToCsv();
    } catch (e) {
      print('Error exporting recording $recordingId to CSV: $e');
      return null;
    }
  }

  // Save exported file to Downloads or user-specified location
  static Future<bool> saveExportedFile({
    required String content,
    required String fileName,
    String? customPath,
  }) async {
    try {
      final filePath = customPath ?? path.join(recordingsPath, '..', 'exports', fileName);
      final file = File(filePath);
      
      // Create exports directory if it doesn't exist
      final parentDir = Directory(path.dirname(filePath));
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      
      await file.writeAsString(content);
      return true;
    } catch (e) {
      print('Error saving exported file $fileName: $e');
      return false;
    }
  }
}