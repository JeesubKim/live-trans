class Caption {
  final String id;
  final String text;
  final DateTime timestamp;
  final Duration startTime;
  final Duration? endTime;
  final double confidence;
  final bool isFinal;
  final String language;

  Caption({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.startTime,
    this.endTime,
    this.confidence = 0.0,
    this.isFinal = false,
    this.language = 'en-US',
  });

  factory Caption.fromJson(Map<String, dynamic> json) {
    return Caption(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      startTime: Duration(milliseconds: json['startTimeMs'] as int),
      endTime: json['endTimeMs'] != null 
          ? Duration(milliseconds: json['endTimeMs'] as int) 
          : null,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isFinal: json['isFinal'] as bool? ?? false,
      language: json['language'] as String? ?? 'en-US',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'startTimeMs': startTime.inMilliseconds,
      'endTimeMs': endTime?.inMilliseconds,
      'confidence': confidence,
      'isFinal': isFinal,
      'language': language,
    };
  }

  Caption copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    Duration? startTime,
    Duration? endTime,
    double? confidence,
    bool? isFinal,
    String? language,
  }) {
    return Caption(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      confidence: confidence ?? this.confidence,
      isFinal: isFinal ?? this.isFinal,
      language: language ?? this.language,
    );
  }

  @override
  String toString() {
    return 'Caption(id: $id, text: $text, confidence: $confidence, isFinal: $isFinal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Caption && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}