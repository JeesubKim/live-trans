import 'package:flutter/material.dart';

class SubtitifyIcon extends StatelessWidget {
  final double size;
  final double fontSize;
  final bool showText;

  const SubtitifyIcon({
    super.key,
    this.size = 80,
    this.fontSize = 10,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: WavePainter(),
        ),
        if (showText)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: size * 0.1,
              vertical: size * 0.05,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(size * 0.08),
            ),
            child: Text(
              'SUBTITIFY',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: fontSize * 0.08,
              ),
            ),
          ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final barWidth = size.width * 0.067; // Relative to size
    final spacing = size.width * 0.1; // Relative to size
    
    // Define different bar heights and border radius for natural wave look
    final List<Map<String, dynamic>> bars = [
      {'height': size.height * 0.25, 'radius': size.width * 0.025},  // Sharp
      {'height': size.height * 0.42, 'radius': size.width * 0.063},  // Medium rounded
      {'height': size.height * 0.58, 'radius': size.width * 0.038},  // Slightly rounded
      {'height': size.height * 0.75, 'radius': size.width * 0.075},  // Very rounded
      {'height': size.height * 0.92, 'radius': size.width * 0.05},  // Medium rounded
      {'height': size.height * 0.67, 'radius': size.width * 0.1},  // Very rounded - center
      {'height': size.height * 0.5, 'radius': size.width * 0.025},  // Sharp
      {'height': size.height * 0.83, 'radius': size.width * 0.088},  // Very rounded  
      {'height': size.height * 0.33, 'radius': size.width * 0.05},  // Medium rounded
      {'height': size.height * 0.58, 'radius': size.width * 0.038},  // Slightly rounded
      {'height': size.height * 0.25, 'radius': size.width * 0.063},  // Medium rounded
    ];
    
    final totalWidth = (bars.length - 1) * spacing + bars.length * barWidth;
    final startX = centerX - totalWidth / 2;
    
    for (int i = 0; i < bars.length; i++) {
      final barHeight = bars[i]['height'] as double;
      final radius = bars[i]['radius'] as double;
      final x = startX + i * (barWidth + spacing);
      final y = centerY - barHeight / 2;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(radius)
      );
      
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}