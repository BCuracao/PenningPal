// Generates PenningPal launcher assets at 1024×1024:
//   assets/icon/app_icon.png            — opaque iOS/App Store master
//   assets/icon/icon_background.png     — solid adaptive background
//   assets/icon/icon_foreground.png     — transparent adaptive foreground
//
// Run from the repo root:
//   dart run tool/generate_penningpal_icon.dart
//
// Rendering is a software SDF rasterizer (no dart:ui) so this stays a
// plain-Dart CLI. Geometry matches assets/icon/penningpal_icon.svg.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int kSize = 1024;

const int kSlateDeep = 0xff0b0f19;
const int kSlateMid = 0xff1e293b;
const int kAmber = 0xfff59e0b;
const int kAmberHot = 0xfffcd34d;
const int kOffWhite = 0xfff8fafc;
const int kMetalShade = 0xffcbd5e1;

void main() {
  final inside = _sdNib(0, 0);
  final outside = _sdNib(400, 0);
  if (inside >= 0 || outside <= 0) {
    stderr.writeln('Nib SDF failed self-check inside=$inside outside=$outside');
    exitCode = 1;
    return;
  }

  final root = Directory.current.path;
  final outDir = Directory('$root/assets/icon')..createSync(recursive: true);

  _writePng(
    File('${outDir.path}/app_icon.png'),
    _render(includeBackground: true, opaque: true, emblemScale: 1.0),
    includeAlpha: false,
  );
  _writePng(
    File('${outDir.path}/icon_background.png'),
    _solid(kSlateDeep),
    includeAlpha: false,
  );
  _writePng(
    File('${outDir.path}/icon_foreground.png'),
    _render(includeBackground: false, opaque: false, emblemScale: 1.12),
    includeAlpha: true,
  );

  stdout.writeln('Wrote 1024×1024 PenningPal icons to ${outDir.path}');
}

Float32List _solid(int argb) {
  final buf = Float32List(kSize * kSize * 4);
  final c = _rgb(argb);
  for (var i = 0; i < buf.length; i += 4) {
    buf[i] = c[0];
    buf[i + 1] = c[1];
    buf[i + 2] = c[2];
    buf[i + 3] = 1;
  }
  return buf;
}

Float32List _render({
  required bool includeBackground,
  required bool opaque,
  required double emblemScale,
}) {
  final buf = Float32List(kSize * kSize * 4);
  const cx = kSize / 2;
  const cy = kSize / 2;
  final white = _rgb(kOffWhite);
  final gold = _rgb(kAmber);
  final goldHot = _rgb(kAmberHot);
  final metal = _rgb(kMetalShade);

  for (var y = 0; y < kSize; y++) {
    for (var x = 0; x < kSize; x++) {
      final i = (y * kSize + x) * 4;
      final px = (x + 0.5 - cx) / emblemScale + cx;
      final py = (y + 0.5 - cy) / emblemScale + cy;

      if (includeBackground) {
        final t = y / (kSize - 1);
        final radial = _length(
          (x + 0.5 - cx) / kSize,
          (y + 0.5 - cy * 0.72) / kSize,
        );
        final lift = _smoothstep(0.85, 0.05, radial) * 0.14;
        final vg = _smoothstep(0.45, 1.15, radial) * 0.16;
        buf[i] = (_mixByte(kSlateDeep, kSlateMid, t, 16) / 255.0 + lift - vg)
            .clamp(0.0, 1.0);
        buf[i + 1] = (_mixByte(kSlateDeep, kSlateMid, t, 8) / 255.0 + lift - vg)
            .clamp(0.0, 1.0);
        buf[i + 2] = (_mixByte(kSlateDeep, kSlateMid, t, 0) / 255.0 + lift - vg)
            .clamp(0.0, 1.0);
        buf[i + 3] = 1;
      } else {
        buf[i] = 0;
        buf[i + 1] = 0;
        buf[i + 2] = 0;
        buf[i + 3] = 0;
      }

      if (includeBackground) {
        final shadow = _cover(_emblemSilhouette(px - 8, py - 16) - 6);
        _blend(buf, i, 0.02, 0.04, 0.08, 0.42 * shadow);
      }

      _paintEmblem(buf, i, px, py, white, gold, goldHot, metal);
    }
  }

  if (opaque) {
    for (var i = 0; i < buf.length; i += 4) {
      buf[i + 3] = 1;
    }
  }
  return buf;
}

void _paintEmblem(
  Float32List buf,
  int i,
  double px,
  double py,
  List<double> white,
  List<double> gold,
  List<double> goldHot,
  List<double> metal,
) {
  const cardCx = 512.0;
  const cardCy = 575.0;
  const cardW = 220.0;
  const cardH = 228.0;
  const cardR = 52.0;
  const stroke = 8.0;

  final cardD = _sdRoundBox(px - cardCx, py - cardCy, cardW, cardH, cardR);
  _blend(buf, i, white[0], white[1], white[2], 0.07 * _cover(cardD));
  _blend(buf, i, white[0], white[1], white[2], _cover(cardD.abs() - stroke));

  _blend(
    buf,
    i,
    white[0],
    white[1],
    white[2],
    0.38 * _cover(_sdCapsule(px, py, 400, 668, 640, 668, 5)),
  );
  _blend(
    buf,
    i,
    white[0],
    white[1],
    white[2],
    0.28 * _cover(_sdCapsule(px, py, 400, 708, 600, 708, 5)),
  );
  _blend(
    buf,
    i,
    white[0],
    white[1],
    white[2],
    0.18 * _cover(_sdCapsule(px, py, 400, 748, 548, 748, 5)),
  );

  const nibCx = 528.0;
  const nibCy = 392.0;
  const angle = 12.0 * math.pi / 180.0;
  final lx = px - nibCx;
  final ly = py - nibCy;
  final cs = math.cos(-angle);
  final sn = math.sin(-angle);
  final nx = lx * cs - ly * sn;
  final ny = lx * sn + ly * cs;

  final nib = _opSub(
    _opSub(_sdNib(nx, ny), _sdCircle(nx, ny + 28, 16)),
    _sdCapsule(nx, ny, 0, -8, 0, 148, 3.1),
  );
  final nibA = _cover(nib);
  if (nibA > 0.001) {
    final goldT = _smoothstep(18, 88, ny);
    final facet = _smoothstep(18, -70, nx);
    var r = _mix(_mix(white[0], metal[0], facet), gold[0], goldT);
    var g = _mix(_mix(white[1], metal[1], facet), gold[1], goldT);
    var b = _mix(_mix(white[2], metal[2], facet), gold[2], goldT);
    final spec =
        math.pow(_smoothstep(90, -10, nx) * _smoothstep(160, 40, ny), 2).toDouble();
    r = (r + spec * (goldHot[0] - r) * 0.55).clamp(0.0, 1.0);
    g = (g + spec * (goldHot[1] - g) * 0.35).clamp(0.0, 1.0);
    b = (b + spec * (goldHot[2] - b) * 0.15).clamp(0.0, 1.0);
    _blend(buf, i, r, g, b, nibA);
  }

  final tineLight = _cover(_sdCapsule(nx, ny, -18, -8, -8, 110, 1.6));
  _blend(
    buf,
    i,
    1,
    1,
    1,
    0.28 * tineLight * (1 - _smoothstep(20, 90, ny)),
  );
}

double _emblemSilhouette(double px, double py) {
  final card = _sdRoundBox(px - 512, py - 575, 220, 228, 52);
  const nibCx = 528.0;
  const nibCy = 392.0;
  const angle = 12.0 * math.pi / 180.0;
  final lx = px - nibCx;
  final ly = py - nibCy;
  final cs = math.cos(-angle);
  final sn = math.sin(-angle);
  final nx = lx * cs - ly * sn;
  final ny = lx * sn + ly * cs;
  final nib = _opSub(
    _opSub(_sdNib(nx, ny), _sdCircle(nx, ny + 28, 16)),
    _sdCapsule(nx, ny, 0, -8, 0, 148, 3.1),
  );
  return math.min(card, nib);
}

double _sdNib(double x, double y) {
  const pts = <double>[
    -52, -152,
    52, -152,
    98, -46,
    0, 158,
    -98, -46,
  ];
  return _sdPolygon(x, y, pts) - 10;
}

double _sdPolygon(double px, double py, List<double> pts) {
  final n = pts.length ~/ 2;
  var d = 1e20;
  var inside = false;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final ix = pts[i * 2];
    final iy = pts[i * 2 + 1];
    final jx = pts[j * 2];
    final jy = pts[j * 2 + 1];
    final ex = jx - ix;
    final ey = jy - iy;
    final wx = px - ix;
    final wy = py - iy;
    final denom = ex * ex + ey * ey;
    final t = denom == 0 ? 0.0 : ((wx * ex + wy * ey) / denom).clamp(0.0, 1.0);
    final bx = wx - ex * t;
    final by = wy - ey * t;
    d = math.min(d, bx * bx + by * by);
    final crosses = (iy > py) != (jy > py);
    if (crosses) {
      final atX = ix + (jx - ix) * (py - iy) / (jy - iy);
      if (px < atX) inside = !inside;
    }
  }
  return (inside ? -1.0 : 1.0) * math.sqrt(d);
}

double _sdRoundBox(double px, double py, double hx, double hy, double r) {
  final qx = px.abs() - hx + r;
  final qy = py.abs() - hy + r;
  return math.min(math.max(qx, qy), 0.0) +
      _length(math.max(qx, 0), math.max(qy, 0)) -
      r;
}

double _sdCircle(double px, double py, double r) => _length(px, py) - r;

double _sdCapsule(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
  double r,
) {
  final pax = px - ax;
  final pay = py - ay;
  final bax = bx - ax;
  final bay = by - ay;
  final h = ((pax * bax + pay * bay) / (bax * bax + bay * bay)).clamp(0.0, 1.0);
  return _length(pax - bax * h, pay - bay * h) - r;
}

double _opSub(double a, double b) => math.max(a, -b);

double _cover(double d) => (0.5 - d).clamp(0.0, 1.0);

double _length(double x, double y) => math.sqrt(x * x + y * y);

double _smoothstep(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _mix(double a, double b, double t) => a + (b - a) * t;

int _mixByte(int a, int b, double t, int shift) {
  final ca = (a >> shift) & 0xff;
  final cb = (b >> shift) & 0xff;
  return (ca + (cb - ca) * t).round();
}

List<double> _rgb(int argb) => [
      ((argb >> 16) & 0xff) / 255.0,
      ((argb >> 8) & 0xff) / 255.0,
      (argb & 0xff) / 255.0,
    ];

void _blend(Float32List buf, int i, double r, double g, double b, double a) {
  if (a <= 0) return;
  a = a.clamp(0.0, 1.0);
  final inv = 1 - a;
  buf[i] = r * a + buf[i] * inv;
  buf[i + 1] = g * a + buf[i + 1] * inv;
  buf[i + 2] = b * a + buf[i + 2] * inv;
  buf[i + 3] = a + buf[i + 3] * inv;
}

void _writePng(File file, Float32List rgba, {required bool includeAlpha}) {
  file.writeAsBytesSync(_encodePng(rgba, includeAlpha: includeAlpha));
}

Uint8List _encodePng(Float32List rgba, {required bool includeAlpha}) {
  final bpp = includeAlpha ? 4 : 3;
  final raw = Uint8List(kSize * (1 + kSize * bpp));
  var o = 0;
  for (var y = 0; y < kSize; y++) {
    raw[o++] = 0;
    for (var x = 0; x < kSize; x++) {
      final i = (y * kSize + x) * 4;
      raw[o++] = (rgba[i] * 255).round().clamp(0, 255);
      raw[o++] = (rgba[i + 1] * 255).round().clamp(0, 255);
      raw[o++] = (rgba[i + 2] * 255).round().clamp(0, 255);
      if (includeAlpha) {
        raw[o++] = (rgba[i + 3] * 255).round().clamp(0, 255);
      }
    }
  }

  final ihdr = ByteData(13);
  ihdr.setUint32(0, kSize);
  ihdr.setUint32(4, kSize);
  ihdr.setUint8(8, 8);
  ihdr.setUint8(9, includeAlpha ? 6 : 2);
  ihdr.setUint8(10, 0);
  ihdr.setUint8(11, 0);
  ihdr.setUint8(12, 0);

  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  _pngChunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _pngChunk(out, 'IDAT', Uint8List.fromList(ZLibEncoder().convert(raw)));
  _pngChunk(out, 'IEND', Uint8List(0));
  return out.takeBytes();
}

void _pngChunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = type.codeUnits;
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);
  final crcSrc = Uint8List(typeBytes.length + data.length);
  crcSrc.setAll(0, typeBytes);
  crcSrc.setAll(typeBytes.length, data);
  final crc = ByteData(4)..setUint32(0, _crc32(crcSrc));
  out.add(crc.buffer.asUint8List());
}

int _crc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final b in data) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}
