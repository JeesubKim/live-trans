import 'package:flutter/material.dart';
import 'live_caption_screen.dart';
import 'recordings_screen.dart';
import '../widgets/subtitify_icon.dart';
import '../widgets/global_toast.dart';
import '../core/core.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  SttLanguage _selectedLanguage = SttLanguage.english;
  SttModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    // Set default model based on selected language
    _selectedModel = _selectedLanguage.recommendedModel;
  }

  void _onLanguageChanged(SttLanguage newLanguage) {
    setState(() {
      _selectedLanguage = newLanguage;
      // Auto-select recommended model for the new language
      _selectedModel = newLanguage.recommendedModel;
    });
    
    TOAST.sendMessage(
      MessageType.normal, 
      'Language changed to ${newLanguage.displayName}. Recommended model: ${newLanguage.recommendedModel.displayName}'
    );
  }

  void _onModelChanged(SttModel newModel) {
    setState(() {
      _selectedModel = newModel;
    });
    
    TOAST.sendMessage(
      MessageType.normal, 
      'STT model changed to ${newModel.displayName}'
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isPortrait = orientation == Orientation.portrait;
            
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: isPortrait ? _buildPortraitLayout() : _buildLandscapeLayout(),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildPortraitLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App logo - Custom Wave with SUBTITIFY text (larger)
        const Center(
          child: SubtitifyIcon(
            size: 120,
            fontSize: 14,
          ),
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
        const SizedBox(height: 24),
        
        // Language selection (same as landscape)
        _buildCompactSelector(
          icon: Icons.language,
          label: 'Language',
          value: _selectedLanguage.displayName,
          items: SttLanguage.values.map((lang) => {
            'value': lang,
            'label': lang.displayName,
          }).toList(),
          onChanged: (value) {
            if (value is SttLanguage) {
              _onLanguageChanged(value);
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // STT Model selection (same as landscape)
        _buildCompactSelector(
          icon: Icons.psychology,
          label: 'STT Model',
          value: _selectedModel?.displayName ?? 'None',
          items: _selectedLanguage.availableModels.map((model) => {
            'value': model,
            'label': '${model.icon} ${model.displayName}${model == _selectedLanguage.recommendedModel ? ' (Recommended)' : ''}',
          }).toList(),
          onChanged: (value) {
            if (value is SttModel) {
              _onModelChanged(value);
            }
          },
        ),
            const SizedBox(height: 24),
            
            // Start button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => 
                        LiveCaptionScreen(
                          selectedLanguage: _selectedLanguage.displayName,
                          selectedModel: _selectedModel?.displayName ?? 'Whisper Base',
                        ),
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
                value: _selectedLanguage.displayName,
                items: SttLanguage.values.map((lang) => {
                  'value': lang,
                  'label': lang.displayName,
                }).toList(),
                onChanged: (value) {
                  if (value is SttLanguage) {
                    _onLanguageChanged(value);
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // STT Model selection (compact)
              _buildCompactSelector(
                icon: Icons.psychology,
                label: 'STT Model',
                value: _selectedModel?.displayName ?? 'None',
                items: _selectedLanguage.availableModels.map((model) => {
                  'value': model,
                  'label': '${model.icon} ${model.displayName}${model == _selectedLanguage.recommendedModel ? ' (Recommended)' : ''}',
                }).toList(),
                onChanged: (value) {
                  if (value is SttModel) {
                    _onModelChanged(value);
                  }
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
                          LiveCaptionScreen(
                            selectedLanguage: _selectedLanguage.displayName,
                            selectedModel: _selectedModel?.displayName ?? 'Whisper Base',
                          ),
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
    required List<Map<String, dynamic>> items,
    required Function(dynamic) onChanged,
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
            child: DropdownButton<dynamic>(
              value: items.firstWhere((item) => item['label'] == value || 
                      (item['value'] is SttLanguage && (item['value'] as SttLanguage).displayName == value) ||
                      (item['value'] is SttModel && (item['value'] as SttModel).displayName == value))['value'],
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
  
}

