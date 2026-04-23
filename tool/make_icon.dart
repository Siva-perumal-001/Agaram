// One-off dev script to generate the launcher icon PNGs. Run with:
//   dart run tool/make_icon.dart
// then `dart run flutter_launcher_icons` to propagate to Android resources.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:image/image.dart';

Future<void> main() async {
  const size = 1024;
  final maroon = ColorRgba8(0x69, 0x00, 0x08, 255);
  final cream = ColorRgba8(0xFF, 0xF8, 0xF7, 255);
  final gold = ColorRgba8(0xD4, 0xA0, 0x17, 255);

  // Full-bleed icon (used for legacy devices).
  final main = Image(width: size, height: size, numChannels: 4);
  fill(main, color: maroon);
  fillCircle(
    main,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: 320,
    color: cream,
  );
  fillCircle(
    main,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: 240,
    color: maroon,
  );
  fillCircle(
    main,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: 180,
    color: gold,
  );
  await File('assets/icon/app_icon.png')
      .writeAsBytes(encodePng(main));

  // Adaptive icon foreground sits on top of the color background; keep it
  // transparent outside and centered the brand mark inside the safe zone
  // (roughly the inner 66% of the canvas).
  final fg = Image(width: size, height: size, numChannels: 4);
  fill(fg, color: ColorRgba8(0, 0, 0, 0));
  fillCircle(fg, x: size ~/ 2, y: size ~/ 2, radius: 260, color: maroon);
  fillCircle(fg, x: size ~/ 2, y: size ~/ 2, radius: 220, color: cream);
  fillCircle(fg, x: size ~/ 2, y: size ~/ 2, radius: 180, color: maroon);
  fillCircle(fg, x: size ~/ 2, y: size ~/ 2, radius: 120, color: gold);
  await File('assets/icon/app_icon_foreground.png')
      .writeAsBytes(encodePng(fg));

  stdout.writeln('Icons written to assets/icon/');
}
