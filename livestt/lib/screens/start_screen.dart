import 'package:flutter/material.dart';
import 'live_caption_screen.dart';
import 'recordings_screen.dart';
import '../widgets/subtitify_icon.dart';
import '../widgets/global_toast.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  String _selectedLanguage = 'en_US';
  String _selectedModel = 'whisper-base';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: isPortrait ? _buildPortraitLayout() : _buildLandscapeLayout(),
          );
        },
      ),
    );
  }
  
  Widget _buildPortraitLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            // App logo - Custom Wave with SUBTITIFY text (larger)
            const SubtitifyIcon(
              size: 120,
              fontSize: 14,
            ),
            const SizedBox(height: 8),
            
            // App description
            const Text(
              'Real-time Speech-to-Text',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            
            // Language selection card
            Card(
              elevation: 4,
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Language',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Language dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      decoration: const InputDecoration(
                        labelText: 'Select Language',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language, color: Colors.grey),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'en_US', child: Text('English (US)')),
                        DropdownMenuItem(value: 'ko_KR', child: Text('Korean')),
                        DropdownMenuItem(value: 'ja_JP', child: Text('Japanese')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value!;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // STT Model dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedModel,
                      decoration: const InputDecoration(
                        labelText: 'STT Model',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.psychology, color: Colors.grey),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'whisper-base', child: Text('Whisper Base')),
                        DropdownMenuItem(value: 'whisper-small', child: Text('Whisper Small')),
                        DropdownMenuItem(value: 'whisper-medium', child: Text('Whisper Medium')),
                        DropdownMenuItem(value: 'whisper-large', child: Text('Whisper Large')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedModel = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Start button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => 
                        const LiveCaptionScreen(),
                    transitionDuration: const Duration(milliseconds: 300),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0); // Start from right
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;

                      var tween = Tween(begin: begin, end: end).chain(
                        CurveTween(curve: curve),
                      );

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic),
                  SizedBox(width: 8),
                  Text(
                    'Start Recording',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // View recordings button
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecordingsScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open),
                  SizedBox(width: 8),
                  Text(
                    'View Recordings',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
      ],
    );
  }
  
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left side - App icon (larger)
        Expanded(
          flex: 3,
          child: Center(
            child: const SubtitifyIcon(
              size: 160,
              fontSize: 18,
            ),
          ),
        ),
        
        const SizedBox(width: 32),
        
        // Right side - Compact controls
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App description
              const Text(
                'Real-time Speech-to-Text',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // Language selection (compact)
              _buildCompactSelector(
                icon: Icons.language,
                label: 'Language',
                value: _getLanguageDisplayName(_selectedLanguage),
                items: const [
                  {'value': 'en_US', 'label': 'English (US)'},
                  {'value': 'ko_KR', 'label': 'Korean'},
                  {'value': 'ja_JP', 'label': 'Japanese'},
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // STT Model selection (compact)
              _buildCompactSelector(
                icon: Icons.psychology,
                label: 'STT Model',
                value: _getModelDisplayName(_selectedModel),
                items: const [
                  {'value': 'whisper-base', 'label': 'Whisper Base'},
                  {'value': 'whisper-small', 'label': 'Whisper Small'},
                  {'value': 'whisper-medium', 'label': 'Whisper Medium'},
                  {'value': 'whisper-large', 'label': 'Whisper Large'},
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedModel = value;
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              // Start button (compact)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => 
                          const LiveCaptionScreen(),
                      transitionDuration: const Duration(milliseconds: 300),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end).chain(
                          CurveTween(curve: curve),
                        );

                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Start Recording',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // View recordings button (compact)
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecordingsScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'View Recordings',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompactSelector({
    required IconData icon,
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: items.firstWhere((item) => item['label'] == value)['value'],
              dropdownColor: Colors.grey[800],
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: Container(),
              isExpanded: true,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item['value']!,
                  child: Text(item['label']!),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'en_US':
        return 'English (US)';
      case 'ko_KR':
        return 'Korean';
      case 'ja_JP':
        return 'Japanese';
      default:
        return code;
    }
  }
  
  String _getModelDisplayName(String model) {
    switch (model) {
      case 'whisper-base':
        return 'Whisper Base';
      case 'whisper-small':
        return 'Whisper Small';
      case 'whisper-medium':
        return 'Whisper Medium';
      case 'whisper-large':
        return 'Whisper Large';
      default:
        return model;
    }
  }
}

