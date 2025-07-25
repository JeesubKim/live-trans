import 'package:flutter/material.dart';
import '../widgets/subtitify_icon.dart';
import '../widgets/global_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 임시 설정 상태들
  bool _autoStart = true;
  bool _saveAudio = true;
  bool _showTimestamp = true;
  double _fontSize = 16.0;
  String _audioQuality = 'high';
  String _language = 'ko_KR';

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
                    TOAST.sendMessage(MessageType.indicator, 'Settings change (UI only)');
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
                    TOAST.sendMessage(MessageType.normal, 'Help feature (UI only)');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback),
                  title: const Text('Send Feedback'),
                  onTap: () {
                    TOAST.sendMessage(MessageType.normal, 'Feedback feature (UI only)');
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
}

