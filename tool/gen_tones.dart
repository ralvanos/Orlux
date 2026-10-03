import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Louder original WAV alerts for Orlux (no third-party samples).
void main() {
  final assets = Directory('assets/sounds')..createSync(recursive: true);
  final raw = Directory('android/app/src/main/res/raw')..createSync(recursive: true);

  final files = <String, Uint8List>{
    'tick': _wav(_burst(freq: 1760, ms: 140, repeats: 1, gapMs: 0)),
    'chime': _wav(_concat([
      _burst(freq: 784, ms: 280, repeats: 1, gapMs: 0),
      _silence(70),
      _burst(freq: 1175, ms: 420, repeats: 1, gapMs: 0),
      _silence(80),
      _burst(freq: 1568, ms: 520, repeats: 1, gapMs: 0),
    ])),
    'bell': _wav(_burst(freq: 494, ms: 900, repeats: 2, gapMs: 120)),
    'pulse': _wav(_burst(freq: 880, ms: 220, repeats: 4, gapMs: 110)),
    'aurora': _wav(_concat([
      _sweep(startHz: 520, endHz: 1040, ms: 420),
      _silence(60),
      _burst(freq: 1040, ms: 380, repeats: 2, gapMs: 90),
    ])),
  };

  for (final entry in files.entries) {
    File('${assets.path}/${entry.key}.wav').writeAsBytesSync(entry.value);
    File('${raw.path}/${entry.key}.wav').writeAsBytesSync(entry.value);
    stdout.writeln('Wrote ${entry.key}.wav (${entry.value.length} bytes)');
  }
}

const _sampleRate = 44100;
const _peak = 0.94;

Uint8List _silence(int ms) => Uint8List(_sampleCount(ms) * 2);

Uint8List _burst({
  required double freq,
  required int ms,
  required int repeats,
  required int gapMs,
}) {
  final parts = <Uint8List>[];
  for (var i = 0; i < repeats; i++) {
    if (i > 0) parts.add(_silence(gapMs));
    parts.add(_tone(freq: freq, ms: ms));
  }
  return _concat(parts);
}

Uint8List _tone({required double freq, required int ms}) {
  final n = _sampleCount(ms);
  final out = ByteData(n * 2);
  final attack = min(n, (_sampleRate * 0.012).round());
  final release = min(n, (_sampleRate * 0.08).round());
  for (var i = 0; i < n; i++) {
    final t = i / _sampleRate;
    var env = 1.0;
    if (i < attack) env = i / attack;
    if (i > n - release) env *= (n - i) / release;
    final wave = sin(2 * pi * freq * t) +
        0.42 * sin(2 * pi * freq * 2 * t) +
        0.22 * sin(2 * pi * freq * 3 * t) +
        0.1 * sin(2 * pi * freq * 4 * t);
    final sample = (env * _peak * (wave / 1.74) * 32767).round().clamp(-32767, 32767);
    out.setInt16(i * 2, sample, Endian.little);
  }
  return out.buffer.asUint8List();
}

Uint8List _sweep({
  required double startHz,
  required double endHz,
  required int ms,
}) {
  final n = _sampleCount(ms);
  final out = ByteData(n * 2);
  var phase = 0.0;
  final attack = min(n, (_sampleRate * 0.02).round());
  final release = min(n, (_sampleRate * 0.06).round());
  for (var i = 0; i < n; i++) {
    final p = n == 1 ? 1.0 : i / (n - 1);
    final freq = startHz + (endHz - startHz) * p;
    phase += 2 * pi * freq / _sampleRate;
    var env = 1.0;
    if (i < attack) env = i / attack;
    if (i > n - release) env *= (n - i) / release;
    final wave = sin(phase) + 0.3 * sin(phase * 2);
    final sample = (env * _peak * (wave / 1.3) * 32767).round().clamp(-32767, 32767);
    out.setInt16(i * 2, sample, Endian.little);
  }
  return out.buffer.asUint8List();
}

Uint8List _concat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (sum, p) => sum + p.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}

int _sampleCount(int ms) => (_sampleRate * ms / 1000).round();

Uint8List _wav(Uint8List pcm) {
  final header = ByteData(44);
  final dataSize = pcm.length;
  final fileSize = 36 + dataSize;
  header.setUint8(0, 0x52);
  header.setUint8(1, 0x49);
  header.setUint8(2, 0x46);
  header.setUint8(3, 0x46);
  header.setUint32(4, fileSize, Endian.little);
  header.setUint8(8, 0x57);
  header.setUint8(9, 0x41);
  header.setUint8(10, 0x56);
  header.setUint8(11, 0x45);
  header.setUint8(12, 0x66);
  header.setUint8(13, 0x6d);
  header.setUint8(14, 0x74);
  header.setUint8(15, 0x20);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, _sampleRate, Endian.little);
  header.setUint32(28, _sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  header.setUint8(36, 0x64);
  header.setUint8(37, 0x61);
  header.setUint8(38, 0x74);
  header.setUint8(39, 0x61);
  header.setUint32(40, dataSize, Endian.little);
  final out = Uint8List(44 + dataSize);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, out.length, pcm);
  return out;
}
