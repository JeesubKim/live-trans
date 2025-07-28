import 'package:flutter/material.dart';

class SubtitifyingComponent extends StatelessWidget {
  final bool isListening;
  final bool isPaused;
  final Animation<double> blinkAnimation;

  const SubtitifyingComponent({
    super.key,
    required this.isListening,
    required this.isPaused,
    required this.blinkAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: blinkAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isListening && !isPaused
                ? Colors.red.withOpacity(blinkAnimation.value * 0.3 + 0.15)
                : Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isListening && !isPaused 
                  ? Colors.red.withOpacity(blinkAnimation.value * 0.8 + 0.2) 
                  : Colors.grey.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: isListening && !isPaused ? [
              BoxShadow(
                color: Colors.red.withOpacity(blinkAnimation.value * 0.5),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.record_voice_over,
                color: isListening && !isPaused 
                    ? Colors.red.withOpacity(blinkAnimation.value) 
                    : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: blinkAnimation,
                builder: (context, child) {
                  return Text(
                    isListening && !isPaused ? 'Subtitifying' : 'Subtitify',
                    style: TextStyle(
                      color: isListening && !isPaused 
                          ? Colors.white.withOpacity(blinkAnimation.value)
                          : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isListening && !isPaused 
                      ? Colors.red.withOpacity(blinkAnimation.value) 
                      : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}