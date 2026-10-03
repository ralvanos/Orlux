import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'key_vault.dart';

class EncryptedStore {
  EncryptedStore({
    KeyVault? keyVault,
    SharedPreferences? prefs,
  })  : _keyVault = keyVault ?? SecureKeyVault(),
        _prefsOverride = prefs;

  static EncryptedStore? _instance;
  static EncryptedStore get instance => _instance ??= EncryptedStore();

  @visibleForTesting
  static void resetInstanceForTest([EncryptedStore? store]) {
    _instance = store;
  }

  static const String blobPrefsKey = 'encrypted_user_data_v1';
  static const String migrationDoneKey = 'encrypted_migration_v1_done';
  static const String _dekVaultKey = 'user_data_dek_v1';

  static const List<String> migratedKeys = [
    'timezone',
    'display_mode',
    'haptics',
    'sound',
    'keep_awake',
    'auto_lock_timeout_seconds',
    'alert_sound_id',
    'custom_sounds',
    'use_24_hour',
    'night_dim_mode',
    'timers',
    'alarms',
  ];

  final KeyVault _keyVault;
  final SharedPreferences? _prefsOverride;

  Map<String, dynamic> _data = {};
  bool _ready = false;
  enc.Key? _dek;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<void> ensureInitialized() async {
    if (_ready) return;
    await _ensureDek();
    await migrateFromPlaintextIfNeeded();
    await _loadBlob();
    _ready = true;
  }

  Future<void> _ensureDek() async {
    var raw = await _keyVault.read(_dekVaultKey);
    if (raw == null || raw.isEmpty) {
      final bytes = Uint8List(32);
      final rng = Random.secure();
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = rng.nextInt(256);
      }
      raw = base64Encode(bytes);
      await _keyVault.write(_dekVaultKey, raw);
    }
    _dek = enc.Key.fromBase64(raw);
  }

  @visibleForTesting
  Future<bool> migrateFromPlaintextIfNeeded({
    SharedPreferences? prefs,
  }) async {
    final storage = prefs ?? await _prefs();
    if (storage.getBool(migrationDoneKey) == true) {
      return false;
    }

    final existingBlob = storage.getString(blobPrefsKey);
    if (existingBlob != null && existingBlob.isEmpty == false) {
      for (final key in migratedKeys) {
        await storage.remove(key);
      }
      await storage.setBool(migrationDoneKey, true);
      return false;
    }

    final snapshot = <String, dynamic>{};
    for (final key in migratedKeys) {
      if (!storage.containsKey(key)) continue;
      final value = storage.get(key);
      if (value == null) continue;
      if (value is List) {
        snapshot[key] = value.map((e) => e.toString()).toList();
      } else {
        snapshot[key] = value;
      }
    }

    if (snapshot.isNotEmpty) {
      _data = Map<String, dynamic>.from(snapshot);
      await _persistBlob(storage);
      for (final key in migratedKeys) {
        await storage.remove(key);
      }
    }

    await storage.setBool(migrationDoneKey, true);
    return snapshot.isNotEmpty;
  }

  Future<void> _loadBlob() async {
    final storage = await _prefs();
    final blob = storage.getString(blobPrefsKey);
    if (blob == null || blob.isEmpty) {
      _data = {};
      return;
    }
    try {
      _data = Map<String, dynamic>.from(jsonDecode(_decrypt(blob)) as Map);
    } catch (e) {
      debugPrint('EncryptedStore: failed to decrypt blob: $e');
      _data = {};
    }
  }

  Future<void> _persistBlob([SharedPreferences? prefs]) async {
    final storage = prefs ?? await _prefs();
    if (_data.isEmpty) {
      await storage.remove(blobPrefsKey);
      return;
    }
    final plaintext = jsonEncode(_data);
    await storage.setString(blobPrefsKey, _encrypt(plaintext));
  }

  String _encrypt(String plaintext) {
    final key = _dek!;
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  String _decrypt(String blob) {
    final parts = blob.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted blob format');
    }
    final key = _dek!;
    final iv = enc.IV.fromBase64(parts[0]);
    final encrypted = enc.Encrypted.fromBase64(parts[1]);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Future<void> _mutate(void Function(Map<String, dynamic> data) update) async {
    await ensureInitialized();
    update(_data);
    await _persistBlob();
  }

  Future<String?> getString(String key) async {
    await ensureInitialized();
    final value = _data[key];
    return value is String ? value : null;
  }

  Future<void> setString(String key, String value) async {
    await _mutate((data) => data[key] = value);
  }

  Future<bool?> getBool(String key) async {
    await ensureInitialized();
    final value = _data[key];
    return value is bool ? value : null;
  }

  Future<void> setBool(String key, bool value) async {
    await _mutate((data) => data[key] = value);
  }

  Future<int?> getInt(String key) async {
    await ensureInitialized();
    final value = _data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Future<void> setInt(String key, int value) async {
    await _mutate((data) => data[key] = value);
  }

  Future<void> remove(String key) async {
    await _mutate((data) => data.remove(key));
  }

  Future<Map<String, dynamic>> exportSnapshot() async {
    await ensureInitialized();
    return Map<String, dynamic>.from(_data);
  }

  Future<void> applyMap(Map<String, dynamic> updates) async {
    await _mutate((data) {
      updates.forEach((key, value) {
        data[key] = value;
      });
    });
  }

  @visibleForTesting
  Map<String, dynamic> debugData() => Map<String, dynamic>.from(_data);

  @visibleForTesting
  String encryptForTest(String plaintext) => _encrypt(plaintext);

  @visibleForTesting
  String decryptForTest(String blob) => _decrypt(blob);
}
