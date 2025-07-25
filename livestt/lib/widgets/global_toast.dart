import 'dart:async';
import 'package:flutter/material.dart';

enum MessageType {
  success,
  fail,
  indicator,
  normal,
}

class ToastMessage {
  final String id;
  final MessageType type;
  final String message;
  final DateTime timestamp;
  Timer? timer;

  ToastMessage({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
  });
}

class ToastManager extends ChangeNotifier {
  static final ToastManager _instance = ToastManager._internal();
  factory ToastManager() => _instance;
  ToastManager._internal();

  final List<ToastMessage> _messages = [];
  List<ToastMessage> get messages => List.unmodifiable(_messages);

  void sendMessage(MessageType type, String message) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final toastMessage = ToastMessage(
      id: id,
      type: type,
      message: message,
      timestamp: DateTime.now(),
    );

    _messages.add(toastMessage);
    notifyListeners();

    // Set 5-second timer for this message
    toastMessage.timer = Timer(const Duration(seconds: 5), () {
      removeMessage(id);
    });
  }

  void removeMessage(String id) {
    final index = _messages.indexWhere((msg) => msg.id == id);
    if (index != -1) {
      _messages[index].timer?.cancel();
      _messages.removeAt(index);
      notifyListeners();
    }
  }

  void clearAll() {
    for (final message in _messages) {
      message.timer?.cancel();
    }
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clearAll();
    super.dispose();
  }
}

// Global toast instance
final TOAST = ToastManager();

class GlobalToastOverlay extends StatefulWidget {
  final Widget child;

  const GlobalToastOverlay({
    super.key,
    required this.child,
  });

  @override
  State<GlobalToastOverlay> createState() => _GlobalToastOverlayState();
}

class _GlobalToastOverlayState extends State<GlobalToastOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    TOAST.addListener(_onToastUpdate);
  }

  @override
  void dispose() {
    TOAST.removeListener(_onToastUpdate);
    _animationController.dispose();
    super.dispose();
  }

  void _onToastUpdate() {
    if (mounted) {
      if (TOAST.messages.isNotEmpty) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      setState(() {});
    }
  }

  Color _getTypeColor(MessageType type) {
    switch (type) {
      case MessageType.success:
        return Colors.green;
      case MessageType.fail:
        return Colors.red;
      case MessageType.indicator:
        return Colors.orange;
      case MessageType.normal:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.success:
        return Icons.check_circle;
      case MessageType.fail:
        return Icons.error;
      case MessageType.indicator:
        return Icons.info;
      case MessageType.normal:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (TOAST.messages.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: TOAST.messages.map((message) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getTypeColor(message.type),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(message.type),
                              color: _getTypeColor(message.type),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                message.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => TOAST.removeMessage(message.id),
                              child: Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}