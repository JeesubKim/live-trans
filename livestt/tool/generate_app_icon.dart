import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../lib/widgets/subtitify_icon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create the app icon widget
  final iconWidget = Container(
    width: 512,
    height: 512,
    color: Colors.transparent,
    child: const SubtitifyIcon(
      size: 512,
      fontSize: 32,
      showText: true,
    ),
  );

  // Convert widget to image
  final repaintBoundary = RepaintBoundary(child: iconWidget);
  final renderRepaintBoundary = RenderRepaintBoundary();
  final renderView = RenderView(
    child: renderRepaintBoundary,
    configuration: const ViewConfiguration(
      size: Size(512, 512),
      devicePixelRatio: 1.0,
    ),
    view: WidgetsBinding.instance.platformDispatcher.views.first,
  );

  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());

  renderView.attach(pipelineOwner);
  renderView.prepareInitialFrame();

  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: renderRepaintBoundary,
    child: iconWidget,
  ).attachToRenderTree(buildOwner);

  buildOwner.buildScope(rootElement);
  buildOwner.finalizeTree();
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();

  final image = await renderRepaintBoundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final uint8List = byteData!.buffer.asUint8List();

  // Create assets directory if it doesn't exist
  final assetsDir = Directory('assets/icon');
  if (!await assetsDir.exists()) {
    await assetsDir.create(recursive: true);
  }

  // Save the icon
  final file = File('assets/icon/app_icon.png');
  await file.writeAsBytes(uint8List);

  print('App icon generated successfully at: ${file.path}');
  print('Run: flutter packages pub run flutter_launcher_icons:main');
}