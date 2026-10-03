import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/clock_sound.dart';
import 'encrypted_store.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _keyCustom = 'custom_sounds';

  static final _alertContext = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  final AudioPlayer _player = AudioPlayer();
  Timer? _ramp;

  Future<Directory> _soundsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'sounds'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<List<CustomSound>> customSounds() async {
    final raw = await EncryptedStore.instance.getString(_keyCustom);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map)
            CustomSound.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCustom(List<CustomSound> sounds) async {
    await EncryptedStore.instance.setString(
      _keyCustom,
      jsonEncode(sounds.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> play({
    required String id,
    required bool enabled,
    bool loop = false,
    bool crescendo = false,
  }) async {
    if (!enabled) return;
    final resolved = SoundCatalog.resolve(id);
    try {
      await _player.stop();
      await _player.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.stop,
      );
      final startVol = (loop && crescendo) ? 0.12 : 1.0;
      await _player.setVolume(startVol);
      final builtIn = SoundCatalog.builtInById(resolved);
      if (builtIn?.asset != null) {
        await _player.play(
          AssetSource(builtIn!.asset!.replaceFirst('assets/', '')),
          volume: startVol,
          ctx: _alertContext,
        );
        _beginCrescendo(loop && crescendo);
        return;
      }
      final customs = await customSounds();
      CustomSound? match;
      for (final sound in customs) {
        if (sound.id == resolved) match = sound;
      }
      if (match == null) {
        await _player.play(
          AssetSource('sounds/chime.wav'),
          volume: startVol,
          ctx: _alertContext,
        );
        _beginCrescendo(loop && crescendo);
        return;
      }
      final file = File(p.join((await _soundsDir()).path, match.fileName));
      if (!file.existsSync()) {
        await _player.play(
          AssetSource('sounds/chime.wav'),
          volume: startVol,
          ctx: _alertContext,
        );
        _beginCrescendo(loop && crescendo);
        return;
      }
      await _player.play(
        DeviceFileSource(file.path),
        volume: startVol,
        ctx: _alertContext,
      );
      _beginCrescendo(loop && crescendo);
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  void _beginCrescendo(bool enabled) {
    _ramp?.cancel();
    if (!enabled) return;
    var vol = 0.12;
    _ramp = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      vol = (vol + 0.12).clamp(0.0, 1.0);
      try {
        await _player.setVolume(vol);
      } catch (_) {}
      if (vol >= 1) timer.cancel();
    });
  }

  Future<void> stop() async {
    _ramp?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> playClick({required bool enabled}) async {
    if (!enabled) return;
    await SystemSound.play(SystemSoundType.click);
  }

  Future<CustomSound?> importSound() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'ogg', 'm4a', 'aac'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    final safeBase = file.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final name = '${DateTime.now().millisecondsSinceEpoch}_$safeBase';
    final dest = File(p.join((await _soundsDir()).path, name));
    await dest.writeAsBytes(bytes, flush: true);
    final sound = CustomSound(
      id: 'custom:$name',
      label: p.basenameWithoutExtension(file.name),
      fileName: name,
    );
    final all = await customSounds();
    all.add(sound);
    await _saveCustom(all);
    return sound;
  }

  Future<void> deleteCustom(String id) async {
    final all = await customSounds();
    CustomSound? match;
    for (final sound in all) {
      if (sound.id == id) match = sound;
    }
    final next = all.where((s) => s.id != id).toList();
    await _saveCustom(next);
    if (match != null) {
      final file = File(p.join((await _soundsDir()).path, match.fileName));
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<AndroidNotificationSound?> notificationSound(String id) async {
    final resolved = SoundCatalog.resolve(id);
    final builtIn = SoundCatalog.builtInById(resolved);
    if (builtIn?.rawName != null) {
      return RawResourceAndroidNotificationSound(builtIn!.rawName);
    }
    if (resolved.startsWith('custom:')) {
      final customs = await customSounds();
      for (final sound in customs) {
        if (sound.id != resolved) continue;
        final file = File(p.join((await _soundsDir()).path, sound.fileName));
        if (file.existsSync()) {
          return UriAndroidNotificationSound(Uri.file(file.path).toString());
        }
      }
    }
    return const RawResourceAndroidNotificationSound('chime');
  }

  String channelSuffix(String id) {
    final cleaned = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    if (cleaned.length <= 24) return cleaned;
    return cleaned.substring(0, 24);
  }
}
