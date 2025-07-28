import 'dart:async';
import 'package:flutter/material.dart';
import '../components/toast_component.dart';

// Legacy MessageType enum for backward compatibility
enum MessageType {
  normal,
  fail,
  indicator,
}

// Convert MessageType to ToastType
ToastType _messageTypeToToastType(MessageType messageType) {
  switch (messageType) {
    case MessageType.normal:
      return ToastType.normal;
    case MessageType.fail:
      return ToastType.error;
    case MessageType.indicator:
      return ToastType.info;
  }
}

class ToastMessage {
  final String id;
  final String message;
  final ToastType type;
  final Duration duration;
  final double opacity;
  final Color? customColor;
  final DateTime timestamp;

  ToastMessage({
    required this.id,
    required this.message,
    this.type = ToastType.normal,
    this.duration = const Duration(seconds: 10), // Default 10 seconds
    this.opacity = 0.7,
    this.customColor,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class GlobalToast extends ChangeNotifier {
  static final GlobalToast _instance = GlobalToast._internal();
  factory GlobalToast() => _instance;
  GlobalToast._internal();

  final List<ToastMessage> _messages = [];
  List<ToastMessage> get messages => List.unmodifiable(_messages);

  void show({
    required String message,
    ToastType type = ToastType.normal,
    Duration? duration,
    double opacity = 0.7,
    Color? customColor,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final toastMessage = ToastMessage(
      id: id,
      message: message,
      type: type,
      duration: duration ?? const Duration(seconds: 10),
      opacity: opacity,
      customColor: customColor,
    );

    _messages.add(toastMessage);
    notifyListeners();

    // Auto dismiss after duration
    Timer(toastMessage.duration, () {
      dismiss(id);
    });
  }

  void dismiss(String id) {
    final index = _messages.indexWhere((msg) => msg.id == id);
    if (index != -1) {
      _messages.removeAt(index);
      notifyListeners();
    }
  }

  void dismissAll() {
    _messages.clear();
    notifyListeners();
  }

  // Convenience methods
  void success(String message, {Duration? duration, double opacity = 0.7}) {
    show(
      message: message,
      type: ToastType.success,
      duration: duration,
      opacity: opacity,
    );
  }

  void error(String message, {Duration? duration, double opacity = 0.7}) {
    show(
      message: message,
      type: ToastType.error,
      duration: duration,
      opacity: opacity,
    );
  }

  void warning(String message, {Duration? duration, double opacity = 0.7}) {
    show(
      message: message,
      type: ToastType.warning,
      duration: duration,
      opacity: opacity,
    );
  }

  void info(String message, {Duration? duration, double opacity = 0.7}) {
    show(
      message: message,
      type: ToastType.info,
      duration: duration,
      opacity: opacity,
    );
  }

  void normal(String message, {Duration? duration, double opacity = 0.7}) {
    show(
      message: message,
      type: ToastType.normal,
      duration: duration,
      opacity: opacity,
    );
  }

  // Legacy sendMessage method for backward compatibility
  void sendMessage(MessageType messageType, String message, {Duration? duration, double opacity = 0.7}) {
    show(
      message: message,
      type: _messageTypeToToastType(messageType),
      duration: duration,
      opacity: opacity,
    );
  }
}

// Global instance
final globalToast = GlobalToast();

// Legacy toast instance for backward compatibility
final toast = globalToast;

// Global Toast Overlay Widget
class GlobalToastOverlay extends StatefulWidget {
  final Widget child;

  const GlobalToastOverlay({
    super.key,
    required this.child,
  });

  @override
  State<GlobalToastOverlay> createState() => _GlobalToastOverlayState();
}

class _GlobalToastOverlayState extends State<GlobalToastOverlay> {
  @override
  void initState() {
    super.initState();
    globalToast.addListener(_onToastUpdate);
  }

  @override
  void dispose() {
    globalToast.removeListener(_onToastUpdate);
    super.dispose();
  }

  void _onToastUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (globalToast.messages.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: globalToast.messages.map((message) {
                return ToastComponent(
                  key: ValueKey(message.id),
                  message: message.message,
                  type: message.type,
                  duration: message.duration,
                  opacity: message.opacity,
                  customColor: message.customColor,
                  onDismiss: () => globalToast.dismiss(message.id),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}