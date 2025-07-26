import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/start_screen.dart';
import 'widgets/global_toast.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set fullscreen mode for entire app
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  runApp(const SubtitifyApp());
}

class SubtitifyApp extends StatelessWidget {
  const SubtitifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SUBTITIFY',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => GlobalToastOverlay(child: child!),
      home: const StartScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
