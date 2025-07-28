import '../services/app_settings_service.dart';

class DebugLogger {
  static final AppSettingsService _settings = AppSettingsService();

  // Get current timestamp string
  static String _getTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
           '${now.minute.toString().padLeft(2, '0')}:'
           '${now.second.toString().padLeft(2, '0')}.'
           '${now.millisecond.toString().padLeft(3, '0')}';
  }

  // Log debug message only if debug logging is enabled
  static void log(String message) {
    if (_settings.debugLoggingEnabled) {
      print('[${_getTimestamp()}] [DEBUG] $message');
    }
  }

  // Log info message (always shown)
  static void info(String message) {
    print('[${_getTimestamp()}] [INFO] $message');
  }

  // Log error message (always shown)
  static void error(String message) {
    print('[${_getTimestamp()}] [ERROR] $message');
  }

  // Log warning message (always shown)
  static void warning(String message) {
    print('[${_getTimestamp()}] [WARNING] $message');
  }
}