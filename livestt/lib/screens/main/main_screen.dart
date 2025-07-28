import 'package:flutter/material.dart';
import '../recording/recording_screen.dart';
import '../recording/recording_files_screen.dart';
import '../../components/subtitify_icon_component.dart';
import '../../components/select_component.dart';
import '../../utils/global_toast.dart';
import '../../core/core.dart';
import '../../services/app_settings_service.dart';
import '../../utils/debug_logger.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  SttLanguage _selectedLanguage = SttLanguage.english;
  SttModel? _selectedModel;
  bool _isCheckingLanguagePack = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndSetDefaults();
  }
  
  Future<void> _loadSettingsAndSetDefaults() async {
    final settings = AppSettingsService();
    await settings.initialize();
    final savedLanguage = settings.selectedLanguage;
    
    setState(() {
      // Map saved language string back to SttLanguage enum
      if (savedLanguage == 'English (US)') {
        _selectedLanguage = SttLanguage.english;
      } else {
        _selectedLanguage = SttLanguage.english; // Default fallback
      }
      _selectedModel = _selectedLanguage.recommendedModel;
    });
  }

  void _onLanguageChanged(SttLanguage newLanguage) async {
    setState(() {
      _selectedLanguage = newLanguage;
      // Auto-select recommended model for the new language
      _selectedModel = newLanguage.recommendedModel;
    });
    
    // Save to settings
    final settings = AppSettingsService();
    await settings.setSelectedLanguage(newLanguage.displayName);
    
    toast.sendMessage(
      MessageType.normal,
      'Language changed to ${newLanguage.displayName}. Recommended model: ${newLanguage.recommendedModel.displayName}'
    );
  }

  void _onModelChanged(SttModel newModel) {
    setState(() {
      _selectedModel = newModel;
    });
    
    toast.sendMessage(
      MessageType.normal,
      'STT model changed to ${newModel.displayName}'
    );
  }

  // Navigate directly to live caption screen
  Future<void> _startRecording() async {
    if (_isCheckingLanguagePack) return;

    setState(() {
      _isCheckingLanguagePack = true;
    });

    try {
      // Since we're using English only and it's always available, go directly
      _navigateToLiveCaptionScreen();
    } catch (e) {
      DebugLogger.error('Error starting recording: $e');
      toast.sendMessage(MessageType.fail, 'Error starting recording: $e');
    } finally {
      setState(() {
        _isCheckingLanguagePack = false;
      });
    }
  }


  // Navigate to live caption screen
  void _navigateToLiveCaptionScreen() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            RecordingScreen(
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
        
        // Language selection
        SelectComponent(
          data: SttLanguage.values.map((lang) => {
            'icon': Icons.language,
            'id': lang.name,
            'displayName': lang.displayName,
            'value': lang,
          }).toList(),
          initial: SttLanguage.values.indexOf(_selectedLanguage),
          onChanged: (selectedItem) {
            final lang = selectedItem['value'] as SttLanguage;
            _onLanguageChanged(lang);
          },
        ),
        
        const SizedBox(height: 16),
        
        // STT Model selection
        SelectComponent(
          data: _selectedLanguage.availableModels.map((model) => {
            'icon': Icons.psychology,
            'id': model.name,
            'displayName': '${model.icon} ${model.displayName}${model == _selectedLanguage.recommendedModel ? ' (Recommended)' : ''}',
            'value': model,
          }).toList(),
          initial: _selectedModel != null ? 
            _selectedLanguage.availableModels.indexOf(_selectedModel!) : 0,
          onChanged: (selectedItem) {
            final model = selectedItem['value'] as SttModel;
            _onModelChanged(model);
          },
        ),
            const SizedBox(height: 24),
            
            // Start button
            ElevatedButton(
              onPressed: _isCheckingLanguagePack ? null : _startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCheckingLanguagePack)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.mic),
                  const SizedBox(width: 8),
                  Text(
                    _isCheckingLanguagePack ? 'Checking...' : 'Start Recording',
                    style: const TextStyle(fontSize: 18),
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
                    builder: (context) => const RecordingFilesScreen(),
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
        const Expanded(
          flex: 3,
          child: Center(
            child: SubtitifyIcon(
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
              SelectComponent(
                data: SttLanguage.values.map((lang) => {
                  'icon': Icons.language,
                  'id': lang.name,
                  'displayName': lang.displayName,
                  'value': lang,
                }).toList(),
                initial: SttLanguage.values.indexOf(_selectedLanguage),
                onChanged: (selectedItem) {
                  final lang = selectedItem['value'] as SttLanguage;
                  _onLanguageChanged(lang);
                },
              ),
              
              const SizedBox(height: 16),
              
              // STT Model selection (compact)
              SelectComponent(
                data: _selectedLanguage.availableModels.map((model) => {
                  'icon': Icons.psychology,
                  'id': model.name,
                  'displayName': '${model.icon} ${model.displayName}${model == _selectedLanguage.recommendedModel ? ' (Recommended)' : ''}',
                  'value': model,
                }).toList(),
                initial: _selectedModel != null ? 
                  _selectedLanguage.availableModels.indexOf(_selectedModel!) : 0,
                onChanged: (selectedItem) {
                  final model = selectedItem['value'] as SttModel;
                  _onModelChanged(model);
                },
              ),
              
              const SizedBox(height: 24),
              
              // Start button (compact)
              ElevatedButton(
                onPressed: _isCheckingLanguagePack ? null : _startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isCheckingLanguagePack)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      const Icon(Icons.mic, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isCheckingLanguagePack ? 'Checking...' : 'Start Recording',
                      style: const TextStyle(fontSize: 14),
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
                      builder: (context) => const RecordingFilesScreen(),
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
  
  
}

