# Subtitify - Real-time Speech-to-Subtitle App

A Flutter application that provides real-time speech-to-text conversion with a movie subtitle-like interface.

## Features Implemented

### 1. Core UI Structure
- **Dark Theme**: Material Design 3 dark theme throughout the app
- **Full-screen Mode**: Immersive experience during recording
- **Responsive Design**: Optimized layouts for both portrait and landscape orientations

### 2. Main Screen (StartScreen)
- Clean interface with custom Subtitify wave icon
- "Start Recording" button with slide transition animation
- Settings and Recordings navigation

### 3. Live Caption Screen
- **Center-positioned Subtitles**: Main subtitles displayed at screen center without boxes
- **Real-time Font Size Preview**: "Subtitify..." preview when adjusting font size
- **Compact Line Spacing**: Optimized line height (0.9) for efficient space usage
- **Font Size Control**: Range from 12 to 140, default 72, with slider and +/- buttons
- **Blinking Recording Indicator**: "Subtitifying" text with animation during recording
- **Control Overlay**: Video player-like controls with slide animations
  - Language selection (English/Korean only)
  - STT model selection
  - Font size adjustment
  - Pause/Resume functionality
- **Caption History**: Previous captions displayed at bottom
- **Auto-hide Controls**: Controls disappear after 10 seconds of inactivity

### 4. Save/Delete Workflow
- **Save Dialog**: Comprehensive recording save interface with scrolling support
  - Recording summary and preview
  - Title and category selection
  - Resume recording option (X button)
- **Slide-to-Delete**: Intuitive swipe gesture for deletion confirmation
  - Color transition animation
  - Full-width slide requirement
- **Navigation**: Save returns to main screen, delete confirmation with proper navigation

### 5. Settings Screen
- **Multilingual Support**: English interface with Korean language option
- **STT Settings**: Language and model selection, auto-start options
- **Recording Settings**: Audio quality and file saving preferences
- **Display Settings**: Font size adjustment
- **App Info**: Version information and help options
- **Modal Scrolling**: All dialogs support overflow scrolling

### 6. Advanced Features
- **Animation System**: 
  - Scale transitions for modals (zoom in effect)
  - Slide animations for controls
  - Fade animations for text preview
- **Timer Management**: Proper cleanup and conflict resolution
- **Responsive Layouts**: Different arrangements for landscape/portrait modes
- **Custom Icons**: Subtitify wave logo with reusable component

### 7. Technical Improvements
- **Performance Optimization**: Efficient state management and animation controllers
- **Error Handling**: Proper disposal of resources and timer management
- **Code Organization**: Modular components and reusable widgets
- **Material Design 3**: Modern UI components and theming

## Project Structure

```
lib/
├── main.dart                 # App entry point with dark theme
├── screens/
│   ├── start_screen.dart     # Main landing screen
│   ├── live_caption_screen.dart  # Recording and caption display
│   ├── recordings_screen.dart    # Saved recordings management
│   └── settings_screen.dart      # App configuration
└── widgets/
    └── subtitify_icon.dart   # Custom wave logo component
```

## Getting Started

1. **Prerequisites**
   - Flutter SDK (>=3.3.3)
   - Dart SDK

2. **Installation**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

4. **Generate app icon** (optional)
   ```bash
   dart tool/generate_app_icon.dart
   flutter packages pub run flutter_launcher_icons:main
   ```

## Development Status

### Completed (Stage 1-2)
- ✅ Complete UI/UX implementation
- ✅ Animation system
- ✅ Navigation and state management
- ✅ Settings and configuration
- ✅ Responsive design

### Pending (Stage 3-4)
- ⏳ Data models and structures
- ⏳ Audio recording service
- ⏳ Speech-to-text integration
- ⏳ File management system

## Design Philosophy

The app follows a movie subtitle aesthetic with:
- **Minimalist Interface**: Clean, distraction-free design
- **Intuitive Controls**: Familiar video player-like interactions
- **Accessibility**: Large, readable fonts with shadow effects
- **Performance**: Smooth animations and responsive interactions

## Technical Stack

- **Framework**: Flutter 3.x
- **Language**: Dart
- **Architecture**: StatefulWidget with proper lifecycle management
- **Animation**: Custom AnimationController implementations
- **State Management**: Built-in setState with optimized rebuilds
- **UI Components**: Material Design 3 widgets

## Development Progress (Todos)

### ✅ Completed Features
1. **1단계: main.dart와 기본 앱 구조만 옮기기 (StartScreen 포함)** - Core app structure migration
2. **2단계: 모든 화면(screens) UI만 옮기기 - 기능 없이 네비게이션만** - UI screens implementation
3. **GUI 수정: 영어화, 다크테마, 영화자막 스타일** - UI/UX improvements
4. **모든 모달 창에 스케일 애니메이션 적용 (작은 것에서 커지는 효과)** - Modal animations
5. **컨트롤 창에 Pause 버튼 추가** - Pause functionality
6. **저장 모달에 X 버튼 추가 (녹음 재개 기능)** - Resume recording feature
7. **삭제 완료시 메인화면으로 이동 수정** - Navigation improvements
8. **툴바에서 뒤로가기 버튼 제거** - UI cleanup
9. **메인화면과 툴바에 STT 모델 선택 기능 추가** - Model selection
10. **녹음 시작 시 전체화면 모드로 전환** - Fullscreen mode
11. **화면 회전 시 Bottom OVERFLOWED 오류 수정** - Responsive design fixes
12. **녹음 화면 landscape 모드에서 언어/엔진 선택기를 같은 row에 배치** - Layout optimization
13. **모든 modal 창에 overflow 시 scrolling 기능 추가 - 문법 오류 수정 완료** - Modal scrolling
14. **Save 버튼 누르면 메인화면으로 돌아가기** - Navigation flow
15. **폰트 크기 변경 시 실시간 미리보기 기능 추가** - Font preview
16. **자막 위치를 화면 정중앙으로 이동 및 박스 테두리 제거** - Subtitle positioning
17. **폰트 크기 범위 및 기본값 조정, 행간 최소화, Subtitify 미리보기 개선** - Font settings
18. **지원 언어를 영어와 한국어만으로 제한, 설정 화면 영어화** - Language localization
19. **README.md 작성 완료** - Documentation
20. **녹음 시 왼쪽 상단에 파형과 시간 표시 기능 추가** - Waveform visualization

### ⏳ Pending Features
21. **3단계: 모델(models)과 기본 데이터 구조 추가** - Data models implementation
22. **4단계: 서비스(services) 하나씩 추가 - 녹음, STT, 설정 순서로** - Backend services integration

### 🎯 Current Focus
The app has completed all UI/UX features and is ready for backend integration. The next phase involves implementing data models and connecting real audio recording and speech-to-text services.