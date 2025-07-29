import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import '../utils/debug_logger.dart';

/// File operation types for the queue
enum FileOperation { append, write, delete, rename }

/// File operation request
class FileOperationRequest {
  final String id;
  final FileOperation operation;
  final String filePath;
  final String? content;
  final String? newPath; // For rename operations
  final Completer<bool> completer;

  FileOperationRequest({
    required this.id,
    required this.operation,
    required this.filePath,
    this.content,
    this.newPath,
  }) : completer = Completer<bool>();

  Future<bool> get future => completer.future;
}

/// Async file queue for non-blocking file operations
/// Processes file operations in background to avoid blocking STT
class AsyncFileQueue {

  final Queue<FileOperationRequest> _queue = Queue<FileOperationRequest>();
  StreamController<FileOperationRequest>? _requestController;
  
  bool _isInitialized = false;
  bool _isProcessing = false;
  StreamSubscription? _processingSubscription;

  /// Initialize the async file queue
  Future<void> initialize() async {
    if (_isInitialized) return;

    DebugLogger.info('🔄 Initializing AsyncFileQueue...');
    
    // Create new StreamController
    _requestController = StreamController<FileOperationRequest>();
    
    // Start background processing
    _processingSubscription = _requestController!.stream.listen(
      _processRequest,
      onError: (error) {
        DebugLogger.error('AsyncFileQueue stream error: $error');
      },
    );

    _isInitialized = true;
    DebugLogger.info('✅ AsyncFileQueue initialized');
  }

  /// Add a request to the queue (non-blocking)
  Future<bool> _addRequest(FileOperationRequest request) {
    if (!_isInitialized || _requestController == null) {
      DebugLogger.warning('AsyncFileQueue not initialized');
      request.completer.complete(false);
      return request.future;
    }

    // Add to queue and trigger processing
    _queue.add(request);
    _requestController!.add(request);
    
    DebugLogger.log('📝 File operation queued: ${request.operation} - ${request.filePath}');
    return request.future;
  }

  /// Process a single request in background
  Future<void> _processRequest(FileOperationRequest request) async {
    if (_isProcessing) {
      // If already processing, just queue it
      return;
    }

    _isProcessing = true;
    
    try {
      bool success = false;
      
      switch (request.operation) {
        case FileOperation.append:
          success = await _performAppend(request.filePath, request.content!);
          break;
        case FileOperation.write:
          success = await _performWrite(request.filePath, request.content!);
          break;
        case FileOperation.delete:
          success = await _performDelete(request.filePath);
          break;
        case FileOperation.rename:
          success = await _performRename(request.filePath, request.newPath!);
          break;
      }

      // Remove from queue
      if (_queue.isNotEmpty && _queue.first.id == request.id) {
        _queue.removeFirst();
      }

      request.completer.complete(success);
      
      DebugLogger.log('✅ File operation completed: ${request.operation} - ${request.filePath}');
    } catch (e) {
      DebugLogger.error('❌ File operation failed: ${request.operation} - $e');
      request.completer.complete(false);
    } finally {
      _isProcessing = false;
      
      // Process next item in queue if available
      if (_queue.isNotEmpty && _requestController != null) {
        final nextRequest = _queue.first;
        _requestController!.add(nextRequest);
      }
    }
  }

  /// Append content to file
  Future<bool> _performAppend(String filePath, String content) async {
    try {
      final file = File(filePath);
      await file.writeAsString(content, mode: FileMode.append);
      return true;
    } catch (e) {
      DebugLogger.error('Error appending to file: $e');
      return false;
    }
  }

  /// Write content to file (overwrite)
  Future<bool> _performWrite(String filePath, String content) async {
    try {
      final file = File(filePath);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      DebugLogger.error('Error writing to file: $e');
      return false;
    }
  }

  /// Delete file
  Future<bool> _performDelete(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        DebugLogger.info('🗑️ File deleted: $filePath');
      }
      return true;
    } catch (e) {
      DebugLogger.error('Error deleting file: $e');
      return false;
    }
  }

  /// Rename/move file
  Future<bool> _performRename(String oldPath, String newPath) async {
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        await file.rename(newPath);
        DebugLogger.info('📁 File moved: $oldPath → $newPath');
      }
      return true;
    } catch (e) {
      DebugLogger.error('Error renaming file: $e');
      return false;
    }
  }

  // Public API methods

  /// Append content to file (non-blocking)
  Future<bool> appendToFile(String filePath, String content) async {
    final request = FileOperationRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operation: FileOperation.append,
      filePath: filePath,
      content: content,
    );
    
    return _addRequest(request);
  }

  /// Write content to file (non-blocking)
  Future<bool> writeToFile(String filePath, String content) async {
    final request = FileOperationRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operation: FileOperation.write,
      filePath: filePath,
      content: content,
    );
    
    return _addRequest(request);
  }

  /// Delete file (non-blocking)
  Future<bool> deleteFile(String filePath) async {
    final request = FileOperationRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operation: FileOperation.delete,
      filePath: filePath,
    );
    
    return _addRequest(request);
  }

  /// Rename/move file (non-blocking)
  Future<bool> renameFile(String oldPath, String newPath) async {
    final request = FileOperationRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operation: FileOperation.rename,
      filePath: oldPath,
      newPath: newPath,
    );
    
    return _addRequest(request);
  }

  /// Get queue statistics
  Map<String, dynamic> getQueueStats() {
    return {
      'queueSize': _queue.length,
      'isProcessing': _isProcessing,
      'isInitialized': _isInitialized,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    DebugLogger.info('🗑️ Disposing AsyncFileQueue...');
    
    // Wait for current operations to complete
    while (_isProcessing && _queue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    _processingSubscription?.cancel();
    _processingSubscription = null;
    
    if (_requestController != null) {
      await _requestController!.close();
      _requestController = null;
    }
    
    _queue.clear();
    _isInitialized = false;
    
    DebugLogger.info('✅ AsyncFileQueue disposed');
  }
}