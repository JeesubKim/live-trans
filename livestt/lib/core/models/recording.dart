import 'caption.dart';

class Recording {
  final String id;
  final String title;
  final String category;
  final DateTime createdAt;
  final Duration duration;
  final List<Caption> captions;
  final String? audioFilePath;
  final RecordingStatus status;

  Recording({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.duration,
    required this.captions,
    this.audioFilePath,
    this.status = RecordingStatus.completed,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      duration: Duration(milliseconds: json['durationMs'] as int),
      captions: (json['captions'] as List<dynamic>)
          .map((captionJson) => Caption.fromJson(captionJson as Map<String, dynamic>))
          .toList(),
      audioFilePath: json['audioFilePath'] as String?,
      status: RecordingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RecordingStatus.completed,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'captions': captions.map((caption) => caption.toJson()).toList(),
      'audioFilePath': audioFilePath,
      'status': status.name,
    };
  }

  Recording copyWith({
    String? id,
    String? title,
    String? category,
    DateTime? createdAt,
    Duration? duration,
    List<Caption>? captions,
    String? audioFilePath,
    RecordingStatus? status,
  }) {
    return Recording(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      captions: captions ?? this.captions,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      status: status ?? this.status,
    );
  }
}

enum RecordingStatus {
  recording,
  paused,
  completed,
  failed,
}

enum RecordingCategory {
  meeting('Meeting'),
  lecture('Lecture'),
  interview('Interview'),
  personal('Personal'),
  other('Other');

  const RecordingCategory(this.displayName);
  final String displayName;
}