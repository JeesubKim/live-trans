import 'dart:async';
import 'package:flutter/material.dart';

enum ToastType {
  success,
  error,
  warning,
  info,
  normal,
}

class ToastComponent extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final double opacity;
  final Color? customColor;
  final VoidCallback? onDismiss;

  const ToastComponent({
    super.key,
    required this.message,
    this.type = ToastType.normal,
    this.duration = const Duration(seconds: 3),
    this.opacity = 0.9,
    this.customColor,
    this.onDismiss,
  });

  @override
  State<ToastComponent> createState() => _ToastComponentState();
}

class _ToastComponentState extends State<ToastComponent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _animationController.forward();

    // Auto dismiss timer
    _dismissTimer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  Color _getTypeColor() {
    if (widget.customColor != null) {
      return widget.customColor!;
    }
    
    switch (widget.type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.error:
        return Colors.red;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.info:
        return Colors.blue;
      case ToastType.normal:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.warning:
        return Icons.warning;
      case ToastType.info:
        return Icons.info;
      case ToastType.normal:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
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
              color: Colors.black.withOpacity(widget.opacity),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getTypeColor(),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getTypeIcon(),
                  color: _getTypeColor(),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _dismiss,
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
      ),
    );
  }
}