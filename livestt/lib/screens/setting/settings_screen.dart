import 'package:flutter/material.dart';
import '../../components/subtitify_icon_component.dart';
import '../../utils/global_toast.dart';
import '../../services/app_settings_service.dart';
import '../../services/speech_to_text_service.dart';
import '../../services/subtitle_display_manager.dart';
import '../../utils/debug_logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettingsService _settings = AppSettingsService();
  
  // 임시 설정 상태들
  bool _autoStart = true;
  bool _saveAudio = true;
  bool _showTimestamp = true;
  bool _debugLogging = false;
  double _fontSize = 16.0;
  String _audioQuality = 'high';
  String _language = 'ko_KR';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.initialize();
    setState(() {
      _debugLogging = _settings.debugLoggingEnabled;
      _fontSize = _settings.fontSize;
      _language = _settings.selectedLanguage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // STT Settings section
          _buildSectionHeader('STT Settings'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Default Language'),
                  subtitle: Text(_getLanguageName(_language)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageDialog(),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.play_arrow),
                  title: const Text('Auto Start STT'),
                  subtitle: const Text('Automatically start speech recognition'),
                  value: _autoStart,
                  onChanged: (value) {
                    setState(() {
                      _autoStart = value;
                    });
                    globalToast.info('Settings change (UI only)');
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.schedule),
                  title: const Text('Show Timestamp'),
                  subtitle: const Text('Display time information in recognized text'),
                  value: _showTimestamp,
                  onChanged: (value) {
                    setState(() {
                      _showTimestamp = value;
                    });
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 녹음 설정 섹션
          _buildSectionHeader('Recording Settings'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.save),
                  title: const Text('Save Audio File'),
                  subtitle: const Text('Save original audio along with STT'),
                  value: _saveAudio,
                  onChanged: (value) {
                    setState(() {
                      _saveAudio = value;
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.high_quality),
                  title: const Text('Recording Quality'),
                  subtitle: Text(_getQualityName(_audioQuality)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showQualityDialog(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 표시 설정 섹션
          _buildSectionHeader('Display Settings'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('Font Size'),
                  subtitle: Text('${_fontSize.toInt()}px'),
                  trailing: SizedBox(
                    width: 120,
                    child: Slider(
                      value: _fontSize,
                      min: 12.0,
                      max: 24.0,
                      divisions: 6,
                      onChanged: (value) {
                        setState(() {
                          _fontSize = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 디버그 설정 섹션
          _buildSectionHeader('Developer Settings'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.bug_report),
                  title: const Text('Debug Logging'),
                  subtitle: const Text('Show detailed logs in console (for developers)'),
                  value: _debugLogging,
                  onChanged: (value) async {
                    setState(() {
                      _debugLogging = value;
                    });
                    await _settings.setDebugLogging(value);
                    globalToast.success(
                      value ? 'Debug logging enabled' : 'Debug logging disabled'
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mic_none),
                  title: const Text('Test Speech Recognition'),
                  subtitle: const Text('Test if STT is working properly'),
                  onTap: () => _testSpeechRecognition(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: const Text('Reset All Settings'),
                  subtitle: const Text('Reset all settings to default values'),
                  onTap: () => _showResetDialog(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 앱 정보 섹션
          _buildSectionHeader('App Info'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version Info'),
                  subtitle: const Text('Subtitify v1.0.0'),
                  onTap: () {
                    _showAboutDialog();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help'),
                  onTap: () {
                    globalToast.normal('Help feature (UI only)');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback),
                  title: const Text('Send Feedback'),
                  onTap: () {
                    globalToast.normal('Feedback feature (UI only)');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: animation, 
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Text('Language Selection'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('English (US)'),
                  value: 'en_US',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() {
                      _language = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Korean'),
                  value: 'ko_KR',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() {
                      _language = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQualityDialog() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: animation, 
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Text('Recording Quality'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('High (128kbps)'),
                  value: 'high',
                  groupValue: _audioQuality,
                  onChanged: (value) {
                    setState(() {
                      _audioQuality = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Medium (64kbps)'),
                  value: 'medium',
                  groupValue: _audioQuality,
                  onChanged: (value) {
                    setState(() {
                      _audioQuality = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Low (32kbps)'),
                  value: 'low',
                  groupValue: _audioQuality,
                  onChanged: (value) {
                    setState(() {
                      _audioQuality = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: animation, 
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AboutDialog(
        applicationName: 'Subtitify',
        applicationVersion: '1.0.0',
        applicationIcon: const SubtitifyIcon(
          size: 48,
          fontSize: 5,
        ),
        children: const [
          Text('Real-time Speech-to-Subtitle App'),
          SizedBox(height: 8),
          Text('Developed by Subtitify Team'),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en_US':
        return 'English (US)';
      case 'ko_KR':
        return 'Korean';
      default:
        return code;
    }
  }

  String _getQualityName(String quality) {
    switch (quality) {
      case 'high':
        return 'High (128kbps)';
      case 'medium':
        return 'Medium (64kbps)';
      case 'low':
        return 'Low (32kbps)';
      default:
        return quality;
    }
  }

  void _testSpeechRecognition() async {
    try {
      globalToast.normal('Testing speech recognition...');
      
      final sttService = SpeechToTextService();
      final subtitleManager = SubtitleDisplayManager();
      
      // Initialize STT
      final initialized = await sttService.initialize();
      if (!initialized) {
        globalToast.error('STT initialization failed');
        return;
      }
      
      // Show STT info
      final capabilities = sttService.getCapabilities();
      DebugLogger.info('STT Test - Capabilities: $capabilities');
      
      // Try to start listening for 5 seconds
      final listening = await sttService.startListening(subtitleManager: subtitleManager);
      if (listening) {
        globalToast.success('STT test started - say something!');
        
        // Stop after 5 seconds
        Future.delayed(const Duration(seconds: 5), () async {
          await sttService.stopListening();
          globalToast.normal('STT test completed');
        });
      } else {
        globalToast.error('Failed to start STT test');
      }
      
    } catch (e) {
      DebugLogger.error('STT test error: $e');
      globalToast.error('STT test error: $e');
    }
  }

  void _showResetDialog() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset Settings'),
          ],
        ),
        content: const Text(
          'This will reset all settings to their default values. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _settings.resetToDefaults();
                await _loadSettings();
                Navigator.pop(context);
                globalToast.success('Settings reset to defaults');
              } catch (e) {
                Navigator.pop(context);
                globalToast.error('Failed to reset settings');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

