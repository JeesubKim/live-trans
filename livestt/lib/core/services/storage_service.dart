import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/recording.dart';

/// Abstract interface for data storage services
abstract class StorageService {
  /// Save a recording to storage
  Future<void> saveRecording(Recording recording);
  
  /// Load a recording by ID
  Future<Recording?> loadRecording(String id);
  
  /// Load all recordings
  Future<List<Recording>> loadAllRecordings();
  
  /// Delete a recording by ID
  Future<bool> deleteRecording(String id);
  
  /// Update an existing recording
  Future<void> updateRecording(Recording recording);
  
  /// Search recordings by title or content
  Future<List<Recording>> searchRecordings(String query);
  
  /// Get recordings by category
  Future<List<Recording>> getRecordingsByCategory(String category);
  
  /// Clean up resources
  Future<void> dispose();
}

/// Exception thrown by storage services
class StorageException implements Exception {
  final String message;
  final StorageErrorType type;
  final dynamic originalError;

  StorageException(this.message, this.type, [this.originalError]);

  @override
  String toString() => 'StorageException: $message (${type.name})';
}

enum StorageErrorType {
  fileNotFound,
  permissionDenied,
  diskSpaceError,
  corruptedData,
  serializationError,
  unknown,
}

/// File-based implementation of StorageService
class FileStorageService implements StorageService {
  static const String _recordingsFileName = 'recordings.json';
  static const String _audioFolderName = 'audio';
  
  String? _appDocumentsPath;
  String? _audioFolderPath;
  final Map<String, Recording> _recordingsCache = {};
  bool _isInitialized = false;

  /// Initialize the storage service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // TODO: Get actual app documents directory
      // For now, use current directory for simulation
      _appDocumentsPath = Directory.current.path;
      _audioFolderPath = '$_appDocumentsPath/$_audioFolderName';
      
      // Create audio folder if it doesn't exist
      final audioDir = Directory(_audioFolderPath!);
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      
      // Load existing recordings
      await _loadRecordingsFromFile();
      
      _isInitialized = true;
    } catch (e) {
      throw StorageException('Failed to initialize storage service', StorageErrorType.unknown, e);
    }
  }

  @override
  Future<void> saveRecording(Recording recording) async {
    await _ensureInitialized();
    
    try {
      _recordingsCache[recording.id] = recording;
      await _saveRecordingsToFile();
    } catch (e) {
      throw StorageException('Failed to save recording', StorageErrorType.unknown, e);
    }
  }

  @override
  Future<Recording?> loadRecording(String id) async {
    await _ensureInitialized();
    return _recordingsCache[id];
  }

  @override
  Future<List<Recording>> loadAllRecordings() async {
    await _ensureInitialized();
    
    // Sort by creation date (newest first)
    final recordings = _recordingsCache.values.toList();
    recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return recordings;
  }

  @override
  Future<bool> deleteRecording(String id) async {
    await _ensureInitialized();
    
    try {
      final recording = _recordingsCache[id];
      if (recording == null) return false;
      
      // Delete audio file if it exists
      if (recording.audioFilePath != null) {
        final audioFile = File(recording.audioFilePath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }
      
      // Remove from cache and save
      _recordingsCache.remove(id);
      await _saveRecordingsToFile();
      
      return true;
    } catch (e) {
      throw StorageException('Failed to delete recording', StorageErrorType.unknown, e);
    }
  }

  @override
  Future<void> updateRecording(Recording recording) async {
    await _ensureInitialized();
    
    if (!_recordingsCache.containsKey(recording.id)) {
      throw StorageException('Recording not found', StorageErrorType.fileNotFound);
    }
    
    await saveRecording(recording);
  }

  @override
  Future<List<Recording>> searchRecordings(String query) async {
    await _ensureInitialized();
    
    final lowercaseQuery = query.toLowerCase();
    
    return _recordingsCache.values.where((recording) {
      // Search in title
      if (recording.title.toLowerCase().contains(lowercaseQuery)) {
        return true;
      }
      
      // Search in captions text
      for (final caption in recording.captions) {
        if (caption.text.toLowerCase().contains(lowercaseQuery)) {
          return true;
        }
      }
      
      return false;
    }).toList();
  }

  @override
  Future<List<Recording>> getRecordingsByCategory(String category) async {
    await _ensureInitialized();
    
    return _recordingsCache.values
        .where((recording) => recording.category == category)
        .toList();
  }

  @override
  Future<void> dispose() async {
    // Save any pending changes
    if (_isInitialized) {
      await _saveRecordingsToFile();
    }
    
    _recordingsCache.clear();
    _isInitialized = false;
  }

  /// Get the path for storing audio files
  String getAudioFilePath(String recordingId) {
    if (_audioFolderPath == null) {
      throw StorageException('Storage service not initialized', StorageErrorType.unknown);
    }
    return '$_audioFolderPath/$recordingId.wav';
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<void> _loadRecordingsFromFile() async {
    try {
      final file = File('$_appDocumentsPath/$_recordingsFileName');
      
      if (!await file.exists()) {
        return; // No existing recordings
      }
      
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final recordingsList = jsonData['recordings'] as List<dynamic>;
      
      _recordingsCache.clear();
      for (final recordingJson in recordingsList) {
        final recording = Recording.fromJson(recordingJson as Map<String, dynamic>);
        _recordingsCache[recording.id] = recording;
      }
    } catch (e) {
      // If file is corrupted or doesn't exist, start with empty cache
      _recordingsCache.clear();
    }
  }

  Future<void> _saveRecordingsToFile() async {
    try {
      final file = File('$_appDocumentsPath/$_recordingsFileName');
      
      final jsonData = {
        'version': '1.0',
        'recordings': _recordingsCache.values.map((r) => r.toJson()).toList(),
      };
      
      final jsonString = jsonEncode(jsonData);
      await file.writeAsString(jsonString);
    } catch (e) {
      throw StorageException('Failed to save recordings to file', StorageErrorType.unknown, e);
    }
  }
}