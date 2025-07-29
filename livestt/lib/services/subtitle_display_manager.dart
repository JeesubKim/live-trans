import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/debug_logger.dart';
import 'temp_file_manager.dart';

// Subtitle item data structure
class SubtitleItem {
  final String text;
  final DateTime timestamp;
  final bool isComplete;
  final bool isConfirmed;
  final double confidence;
  final String id;

  SubtitleItem({
    required this.text,
    required this.timestamp,
    this.isComplete = false,
    this.isConfirmed = false,
    this.confidence = 1.0,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  SubtitleItem copyWith({
    String? text,
    DateTime? timestamp,
    bool? isComplete,
    bool? isConfirmed,
    double? confidence,
  }) {
    return SubtitleItem(
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isComplete: isComplete ?? this.isComplete,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confidence: confidence ?? this.confidence,
      id: id,
    );
  }

  @override
  String toString() => 'SubtitleItem(text: "$text", confidence: $confidence, isComplete: $isComplete)';
}

class SubtitleDisplayManager {
  // Stream controllers for different data types
  final StreamController<List<SubtitleItem>> _historyController = StreamController<List<SubtitleItem>>.broadcast();
  final StreamController<SubtitleItem?> _currentController = StreamController<SubtitleItem?>.broadcast();
  final StreamController<String> _realtimeController = StreamController<String>.broadcast();

  // Current subtitle data
  final List<SubtitleItem> _history = [];
  SubtitleItem? _currentItem;
  String _realtimeText = '';
  String _lastConfirmedText = '';

  // Configuration - Optimized for memory efficiency
  int _maxVisibleItems = 3; // Portrait default
  final int _maxHistoryItems = 20; // Reduced from 50 to save memory
  
  // Temp file manager for auto-saving
  final TempFileManager _tempFileManager = TempFileManager();
  bool _isSessionActive = false;
  String? _currentSessionId;
  DateTime? _recordingStartTime;
  
  // Stream controllers
  Stream<List<SubtitleItem>> get historyStream => _historyController.stream;
  Stream<SubtitleItem?> get currentStream => _currentController.stream;
  Stream<String> get realtimeStream => _realtimeController.stream;

  // Getters
  SubtitleItem? get currentItem => _currentItem;
  String get realtimeText => _realtimeText;
  List<SubtitleItem> get visibleHistory {
    final start = math.max(0, _history.length - _maxVisibleItems);
    return _history.sublist(start);
  }

  // Update max visible items based on screen orientation
  void updateMaxVisibleItems(int maxItems) {
    _maxVisibleItems = maxItems;
    _notifyHistoryUpdate();
  }

  // Update configuration (for backward compatibility)
  void updateConfiguration({
    int? maxVisibleItems,
    dynamic orientation,
    dynamic screenSize,
  }) {
    if (maxVisibleItems != null) {
      _maxVisibleItems = maxVisibleItems;
      _notifyHistoryUpdate();
    }
    // orientation and screenSize parameters are accepted but not used currently
    // Can be used for future enhancements
  }

  /// Initialize temp file manager
  Future<void> initialize() async {
    try {
      await _tempFileManager.initialize();
      DebugLogger.info('✅ SubtitleDisplayManager initialized with auto-save');
    } catch (e) {
      DebugLogger.error('❌ Failed to initialize SubtitleDisplayManager: $e');
    }
  }

  /// Start a new recording session with auto-save
  Future<String?> startSession() async {
    try {
      if (_isSessionActive) {
        DebugLogger.warning('Session already active, ending previous session');
        await endSession(save: false);
      }

      _currentSessionId = await _tempFileManager.startSession();
      _isSessionActive = true;
      _recordingStartTime = DateTime.now(); // Set recording start time
      
      DebugLogger.info('🚀 Recording session started with auto-save: $_currentSessionId');
      return _currentSessionId;
    } catch (e) {
      DebugLogger.error('❌ Failed to start session: $e');
      return null;
    }
  }

  /// End current recording session
  Future<String?> endSession({
    bool save = true,
    String? title,
    String? category,
    String? language,
    String? model,
    Duration? duration,
  }) async {
    if (!_isSessionActive || _currentSessionId == null) {
      DebugLogger.warning('No active session to end');
      return null;
    }

    try {
      String? finalFilePath;
      
      if (save && title != null) {
        // Save session as permanent file
        finalFilePath = await _tempFileManager.finalizeSession(
          title: title,
          category: category ?? 'Recording',
          language: language ?? 'English',
          model: model ?? 'Android STT Engine',
          duration: duration,
        );
        DebugLogger.info('💾 Session saved: $finalFilePath');
      } else {
        // Discard session
        await _tempFileManager.discardSession();
        DebugLogger.info('🗑️ Session discarded');
      }

      _isSessionActive = false;
      _currentSessionId = null;
      _recordingStartTime = null; // Reset recording start time
      
      return finalFilePath;
    } catch (e) {
      DebugLogger.error('❌ Failed to end session: $e');
      return null;
    }
  }

  /// Check if session is currently active
  bool get isSessionActive => _isSessionActive;

  /// Get current session info
  Map<String, dynamic>? get currentSessionInfo => _tempFileManager.getCurrentSessionInfo();

  // Add item to history
  void addItem(SubtitleItem item) {
    _addToHistory(item);
  }

  // Add realtime text (STT partial result)
  void updateRealtimeText(String text) {
    try {
      // If this is a completely new text (not starting with confirmed text), 
      // it means new speech started - clear previous confirmed text
      if (_lastConfirmedText.isNotEmpty && !text.startsWith(_lastConfirmedText.split(' ').first)) {
        DebugLogger.info('🆕 New speech detected, clearing previous confirmed text');
        _lastConfirmedText = '';
      }
      
      _realtimeText = text;
      // Schedule stream update asynchronously to avoid blocking STT
      Future.microtask(() {
        if (!_realtimeController.isClosed) {
          _realtimeController.add(_realtimeText);
        }
      });
      DebugLogger.info('📝 Realtime updated: "$text" (session: $_isSessionActive, sessionId: $_currentSessionId)');
    } catch (e) {
      DebugLogger.error('❌ Error updating realtime text: $e');
    }
  }

  // Confirm current realtime text (STT final result)
  void confirmRealtimeText({String? finalText, double confidence = 1.0}) {
    final textToConfirm = finalText ?? _realtimeText;
    DebugLogger.info('🎯 confirmRealtimeText called: "$textToConfirm" (session active: $_isSessionActive)');
    if (textToConfirm.isNotEmpty) {
      // Calculate relative timestamp from recording start (0-based)
      final elapsedTime = _recordingStartTime != null 
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;
      final relativeTimestamp = DateTime.fromMillisecondsSinceEpoch(elapsedTime.inMilliseconds);
          
      final newItem = SubtitleItem(
        text: textToConfirm,
        timestamp: relativeTimestamp,
        isComplete: true,
        isConfirmed: true,
        confidence: confidence,
      );

      // Move current to history if exists
      if (_currentItem != null) {
        _addToHistory(_currentItem!);
      }

      // Set new current item
      _currentItem = newItem;
      
      // Auto-save to temp file (non-blocking)
      if (_isSessionActive) {
        Future.microtask(() async {
          try {
            await _tempFileManager.addSubtitle(newItem);
            DebugLogger.log('💾 Auto-saved: "${newItem.text}"');
          } catch (e) {
            DebugLogger.error('❌ Auto-save failed: $e');
          }
        });
      }
      
      // Schedule stream update asynchronously to avoid blocking STT
      Future.microtask(() {
        if (!_currentController.isClosed) {
          _currentController.add(_currentItem);
        }
      });

      // Keep confirmed text visible until new speech starts
      _lastConfirmedText = textToConfirm;
      DebugLogger.info('📝 Current subtitle updated: $textToConfirm');
      DebugLogger.info('📝 Confirmed text kept visible: "$textToConfirm"');
      
      DebugLogger.log('✅ Confirmed text: ${newItem.text}');
    }
  }

  // Add current item to history and clear current
  void finalizeCurrentItem() {
    if (_currentItem != null) {
      _addToHistory(_currentItem!);
      _currentItem = null;
      if (!_currentController.isClosed) {
        _currentController.add(_currentItem);
      }
    }
  }

  // Add item to history
  void _addToHistory(SubtitleItem item) {
    _history.insert(0, item); // Add to beginning (most recent first)

    // Maintain history size limit
    if (_history.length > _maxHistoryItems) {
      _history.removeRange(_maxHistoryItems, _history.length);
    }

    _notifyHistoryUpdate();
  }

  // Notify history update
  void _notifyHistoryUpdate() {
    final visibleHistory = this.visibleHistory;
    // Schedule stream update asynchronously to avoid blocking STT
    Future.microtask(() {
      if (!_historyController.isClosed) {
        _historyController.add(visibleHistory);
      }
    });
  }

  // Clear all data
  void clearAll() {
    _history.clear();
    _currentItem = null;
    _realtimeText = '';
    _lastConfirmedText = '';

    final visibleHistory = this.visibleHistory;
    if (!_historyController.isClosed) {
      _historyController.add(visibleHistory);
    }
    if (!_currentController.isClosed) {
      _currentController.add(_currentItem);
    }
    if (!_realtimeController.isClosed) {
      _realtimeController.add(_realtimeText);
    }
  }

  // Get full history (including current item)
  List<SubtitleItem> getFullHistory() {
    final fullList = <SubtitleItem>[];
    if (_currentItem != null) {
      fullList.add(_currentItem!);
    }
    fullList.addAll(_history);
    return fullList;
  }

  // Get combined text for saving
  String getCombinedText() {
    final items = getFullHistory();
    return items.map((item) => item.text).join(' ');
  }

  // Export to various formats
  Map<String, dynamic> exportToJson() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'items': getFullHistory().map((item) => {
        'text': item.text,
        'timestamp': item.timestamp.toIso8601String(),
        'confidence': item.confidence,
        'isComplete': item.isComplete,
        'isConfirmed': item.isConfirmed,
      }).toList(),
    };
  }

  // Get status info
  Map<String, dynamic> getStatus() {
    return {
      'totalItems': _history.length + (_currentItem != null ? 1 : 0),
      'historyItems': _history.length,
      'hasCurrentItem': _currentItem != null,
      'hasRealtimeText': _realtimeText.isNotEmpty,
      'visibleItems': _maxVisibleItems,
    };
  }

  // Dispose resources
  Future<void> dispose() async {
    DebugLogger.info('🗑️ Disposing SubtitleDisplayManager...');
    
    // End active session if exists
    if (_isSessionActive) {
      await endSession(save: false); // Discard on disposal
    }
    
    // Dispose temp file manager
    await _tempFileManager.dispose();
    
    // Close stream controllers
    _historyController.close();
    _currentController.close();
    _realtimeController.close();
    
    DebugLogger.info('✅ SubtitleDisplayManager disposed');
  }
}