// Generates the tray / menu-bar icons in assets/tray/:
//
//   dart run tool/make_tray_icons.dart
//
// - tray_icon_macos_template.png: a black microphone on transparency, 36×36
//   (18 pt @2x). macOS treats it as a template image and tints it for the
//   menu bar's light or dark appearance.
// - tray_icon.ico: a white microphone on a purple disc, 16/32/48 px, for the
//   Windows notification area (readable on light and dark taskbars).
//
// Drawn from simple shapes with 4×4 supersampling, so the output is
// reproducible and carries no third-party rights. No dependencies: PNG and
// ICO are written by hand.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  final out = Directory.fromUri(Platform.script.resolve('../assets/tray/'))
    ..createSync(recursive: true);
  File('${out.path}/tray_icon_macos_template.png').writeAsBytesSync(
    _png(36, _render(36, template: true)),
  );
  File('${out.path}/tray_icon.ico').writeAsBytesSync(
    _ico({
      for (final s in [16, 32, 48]) s: _png(s, _render(s, template: false)),
    }),
  );
  stdout.writeln('Wrote ${out.path}');
}

/// Coverage (0…1) of the microphone glyph at (x, y) in a unit square.
double _mic(double x, double y) {
  // Capsule: the head of the microphone.
  final capsule = _capsule(x, y, 0.5, 0.16, 0.5, 0.5, 0.15);
  // U-shaped holder around the lower half of the capsule.
  final dx = x - 0.5, dy = y - 0.46;
  final r = math.sqrt(dx * dx + dy * dy);
  final holder = (dy > 0 && (r - 0.25).abs() < 0.045) ? 1.0 : 0.0;
  final holderEnds =
      _capsule(x, y, 0.25, 0.4, 0.25, 0.46, 0.045) +
      _capsule(x, y, 0.75, 0.4, 0.75, 0.46, 0.045);
  // Stem and base.
  final stem = _capsule(x, y, 0.5, 0.71, 0.5, 0.84, 0.045);
  final base = _capsule(x, y, 0.33, 0.86, 0.67, 0.86, 0.045);
  return math.min(1, capsule + holder + holderEnds + stem + base);
}

/// 1 inside a capsule from (x0, y0) to (x1, y1) with radius r, else 0.
double _capsule(
  double x,
  double y,
  double x0,
  double y0,
  double x1,
  double y1,
  double r,
) {
  final vx = x1 - x0, vy = y1 - y0;
  final len2 = vx * vx + vy * vy;
  final t = len2 == 0
      ? 0.0
      : (((x - x0) * vx + (y - y0) * vy) / len2).clamp(0.0, 1.0);
  final px = x0 + t * vx - x, py = y0 + t * vy - y;
  return px * px + py * py <= r * r ? 1.0 : 0.0;
}

/// RGBA pixels of a `size`×`size` icon.
Uint8List _render(int size, {required bool template}) {
  const ss = 4;
  final px = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var mic = 0.0, disc = 0.0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final u = (x + (sx + 0.5) / ss) / size;
          final v = (y + (sy + 0.5) / ss) / size;
          if (template) {
            mic += _mic(u, v);
          } else {
            // Shrink the glyph a little inside the disc.
            mic += _mic(0.5 + (u - 0.5) * 1.35, 0.5 + (v - 0.5) * 1.35);
            final du = u - 0.5, dv = v - 0.5;
            disc += du * du + dv * dv <= 0.25 ? 1 : 0;
          }
        }
      }
      mic /= ss * ss;
      disc /= ss * ss;
      final i = (y * size + x) * 4;
      if (template) {
        px[i + 3] = (mic * 255).round(); // black, alpha = coverage
      } else {
        // White mic over a #5B3FC4 disc.
        final m = mic * disc;
        px[i] = (0x5B + (255 - 0x5B) * m).round();
        px[i + 1] = (0x3F + (255 - 0x3F) * m).round();
        px[i + 2] = (0xC4 + (255 - 0xC4) * m).round();
        px[i + 3] = (disc * 255).round();
      }
    }
  }
  return px;
}

Uint8List _png(int size, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw
      ..addByte(0) // filter: none
      ..add(rgba.sublist(y * size * 4, (y + 1) * size * 4));
  }
  final ihdr = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  return (BytesBuilder()
        ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', ihdr.buffer.asUint8List()))
        ..add(_chunk('IDAT', zlib.encode(raw.toBytes())))
        ..add(_chunk('IEND', const [])))
      .toBytes();
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final len = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
  return [
    ...len.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crc.buffer.asUint8List(),
  ];
}

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// An ICO file holding PNG images (supported since Windows Vista).
Uint8List _ico(Map<int, Uint8List> pngs) {
  final header = ByteData(6)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little) // icon
    ..setUint16(4, pngs.length, Endian.little);
  final out = BytesBuilder()..add(header.buffer.asUint8List());
  var offset = 6 + 16 * pngs.length;
  for (final MapEntry(key: size, value: png) in pngs.entries) {
    final e = ByteData(16)
      ..setUint8(0, size >= 256 ? 0 : size)
      ..setUint8(1, size >= 256 ? 0 : size)
      ..setUint8(2, 0)
      ..setUint8(3, 0)
      ..setUint16(4, 1, Endian.little) // planes
      ..setUint16(6, 32, Endian.little) // bits per pixel
      ..setUint32(8, png.length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    out.add(e.buffer.asUint8List());
    offset += png.length;
  }
  for (final png in pngs.values) {
    out.add(png);
  }
  return out.toBytes();
}
