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
      model: SttModel.deviceDefault,
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
        orElse: () => SttModel.deviceDefault,
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
  english('en-US', 'English (US)');

  const SttLanguage(this.code, this.displayName);
  final String code;
  final String displayName;

  /// Get available STT models for this language
  List<SttModel> get availableModels {
    switch (this) {
      case SttLanguage.english:
        return [
          SttModel.deviceDefault,
        ];
    }
  }

  /// Get the recommended (best) model for this language
  SttModel get recommendedModel {
    switch (this) {
      case SttLanguage.english:
        return SttModel.deviceDefault;
    }
  }
}

enum SttModel {
  // Device default (offline) - Android STT Engine
  deviceDefault('device-default', 'Android STT Engine', SttProvider.device, false);

  const SttModel(this.id, this.displayName, this.provider, this.requiresInternet);
  final String id;
  final String displayName;
  final SttProvider provider;
  final bool requiresInternet;

  /// Get model description with additional info
  String get description {
    final internetInfo = requiresInternet ? '(Requires Internet)' : '(Offline)';
    switch (this) {
      case SttModel.deviceDefault:
        return 'Uses Android built-in speech recognition - Fast and reliable $internetInfo';
    }
  }

  /// Get model icon
  String get icon {
    switch (provider) {
      case SttProvider.device:
        return '📱'; // Android device icon
      case SttProvider.openai:
        return '🤖'; // OpenAI Whisper icon (unused now)
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