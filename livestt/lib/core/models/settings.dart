class AppSettings {
  final SttSettings sttSettings;
  final RecordingSettings recordingSettings;
  final DisplaySettings displaySettings;

  AppSettings({
    required this.sttSettings,
    required this.recordingSettings,
    required this.displaySettings,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      sttSettings: SttSettings.defaultSettings(),
      recordingSettings: RecordingSettings.defaultSettings(),
      displaySettings: DisplaySettings.defaultSettings(),
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      sttSettings: SttSettings.fromJson(json['sttSettings'] as Map<String, dynamic>),
      recordingSettings: RecordingSettings.fromJson(json['recordingSettings'] as Map<String, dynamic>),
      displaySettings: DisplaySettings.fromJson(json['displaySettings'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sttSettings': sttSettings.toJson(),
      'recordingSettings': recordingSettings.toJson(),
      'displaySettings': displaySettings.toJson(),
    };
  }

  AppSettings copyWith({
    SttSettings? sttSettings,
    RecordingSettings? recordingSettings,
    DisplaySettings? displaySettings,
  }) {
    return AppSettings(
      sttSettings: sttSettings ?? this.sttSettings,
      recordingSettings: recordingSettings ?? this.recordingSettings,
      displaySettings: displaySettings ?? this.displaySettings,
    );
  }
}

class SttSettings {
  final SttLanguage language;
  final SttModel model;
  final bool autoStart;
  final bool showTimestamp;
  final double confidenceThreshold;

  SttSettings({
    required this.language,
    required this.model,
    this.autoStart = true,
    this.showTimestamp = true,
    this.confidenceThreshold = 0.5,
  });

  factory SttSettings.defaultSettings() {
    return SttSettings(
      language: SttLanguage.english,
      model: SttModel.whisperBase,
      autoStart: true,
      showTimestamp: true,
      confidenceThreshold: 0.5,
    );
  }

  factory SttSettings.fromJson(Map<String, dynamic> json) {
    return SttSettings(
      language: SttLanguage.values.firstWhere(
        (e) => e.code == json['language'],
        orElse: () => SttLanguage.english,
      ),
      model: SttModel.values.firstWhere(
        (e) => e.id == json['model'],
        orElse: () => SttModel.whisperBase,
      ),
      autoStart: json['autoStart'] as bool? ?? true,
      showTimestamp: json['showTimestamp'] as bool? ?? true,
      confidenceThreshold: (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language.code,
      'model': model.id,
      'autoStart': autoStart,
      'showTimestamp': showTimestamp,
      'confidenceThreshold': confidenceThreshold,
    };
  }

  SttSettings copyWith({
    SttLanguage? language,
    SttModel? model,
    bool? autoStart,
    bool? showTimestamp,
    double? confidenceThreshold,
  }) {
    return SttSettings(
      language: language ?? this.language,
      model: model ?? this.model,
      autoStart: autoStart ?? this.autoStart,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
    );
  }
}

class RecordingSettings {
  final AudioQuality audioQuality;
  final bool saveAudioFile;
  final bool autoSave;
  final String defaultCategory;

  RecordingSettings({
    required this.audioQuality,
    this.saveAudioFile = true,
    this.autoSave = false,
    this.defaultCategory = 'Personal',
  });

  factory RecordingSettings.defaultSettings() {
    return RecordingSettings(
      audioQuality: AudioQuality.high,
      saveAudioFile: true,
      autoSave: false,
      defaultCategory: 'Personal',
    );
  }

  factory RecordingSettings.fromJson(Map<String, dynamic> json) {
    return RecordingSettings(
      audioQuality: AudioQuality.values.firstWhere(
        (e) => e.id == json['audioQuality'],
        orElse: () => AudioQuality.high,
      ),
      saveAudioFile: json['saveAudioFile'] as bool? ?? true,
      autoSave: json['autoSave'] as bool? ?? false,
      defaultCategory: json['defaultCategory'] as String? ?? 'Personal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioQuality': audioQuality.id,
      'saveAudioFile': saveAudioFile,
      'autoSave': autoSave,
      'defaultCategory': defaultCategory,
    };
  }

  RecordingSettings copyWith({
    AudioQuality? audioQuality,
    bool? saveAudioFile,
    bool? autoSave,
    String? defaultCategory,
  }) {
    return RecordingSettings(
      audioQuality: audioQuality ?? this.audioQuality,
      saveAudioFile: saveAudioFile ?? this.saveAudioFile,
      autoSave: autoSave ?? this.autoSave,
      defaultCategory: defaultCategory ?? this.defaultCategory,
    );
  }
}

class DisplaySettings {
  final double fontSize;
  final bool showFontPreview;

  DisplaySettings({
    this.fontSize = 72.0,
    this.showFontPreview = true,
  });

  factory DisplaySettings.defaultSettings() {
    return DisplaySettings(
      fontSize: 72.0,
      showFontPreview: true,
    );
  }

  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 72.0,
      showFontPreview: json['showFontPreview'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'showFontPreview': showFontPreview,
    };
  }

  DisplaySettings copyWith({
    double? fontSize,
    bool? showFontPreview,
  }) {
    return DisplaySettings(
      fontSize: fontSize ?? this.fontSize,
      showFontPreview: showFontPreview ?? this.showFontPreview,
    );
  }
}

enum SttLanguage {
  english('en-US', 'English (US)'),
  korean('ko-KR', 'Korean');

  const SttLanguage(this.code, this.displayName);
  final String code;
  final String displayName;

  /// Get available STT models for this language
  List<SttModel> get availableModels {
    switch (this) {
      case SttLanguage.english:
        return [
          SttModel.whisperBase,
          SttModel.whisperSmall,
          SttModel.whisperMedium,
          SttModel.whisperLarge,
          SttModel.deviceDefault,
        ];
      case SttLanguage.korean:
        return [
          SttModel.whisperBase,
          SttModel.whisperSmall,
          SttModel.whisperMedium,
          SttModel.whisperLarge,
          SttModel.deviceDefault,
        ];
    }
  }

  /// Get the recommended (best) model for this language
  SttModel get recommendedModel {
    switch (this) {
      case SttLanguage.english:
        return SttModel.whisperMedium;
      case SttLanguage.korean:
        return SttModel.whisperMedium; // Good balance for Korean too
    }
  }
}

enum SttModel {
  // OpenAI Whisper models (offline)
  whisperBase('whisper-base', 'Whisper Base', SttProvider.openai, false),
  whisperSmall('whisper-small', 'Whisper Small', SttProvider.openai, false),
  whisperMedium('whisper-medium', 'Whisper Medium', SttProvider.openai, false),
  whisperLarge('whisper-large', 'Whisper Large', SttProvider.openai, false),
  
  // Device default (offline)
  deviceDefault('device-default', 'Device Default', SttProvider.device, false);

  const SttModel(this.id, this.displayName, this.provider, this.requiresInternet);
  final String id;
  final String displayName;
  final SttProvider provider;
  final bool requiresInternet;

  /// Get model description with additional info
  String get description {
    final internetInfo = requiresInternet ? '(Requires Internet)' : '(Offline)';
    switch (this) {
      case SttModel.whisperBase:
        return 'Fast, lightweight model - Good for real-time processing $internetInfo';
      case SttModel.whisperSmall:
        return 'Good balance of speed and accuracy - Recommended for most users $internetInfo';
      case SttModel.whisperMedium:
        return 'High accuracy, moderate speed - Best overall performance $internetInfo';
      case SttModel.whisperLarge:
        return 'Highest accuracy, slower processing - For maximum quality $internetInfo';
      case SttModel.deviceDefault:
        return 'Uses system built-in speech recognition - Varies by device $internetInfo';
    }
  }

  /// Get model icon
  String get icon {
    switch (provider) {
      case SttProvider.openai:
        return '🤖'; // OpenAI Whisper icon
      case SttProvider.device:
        return '📻'; // Device icon
    }
  }
}

enum SttProvider {
  openai,
  device,
}

enum AudioQuality {
  low('low', 'Low (32kbps)', 32),
  medium('medium', 'Medium (64kbps)', 64),
  high('high', 'High (128kbps)', 128);

  const AudioQuality(this.id, this.displayName, this.bitrate);
  final String id;
  final String displayName;
  final int bitrate;
}