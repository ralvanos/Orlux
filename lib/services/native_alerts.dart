import 'dart:convert';

import 'package:flutter/services.dart';

class NativeAlerts {
  NativeAlerts._();

  static const channel = MethodChannel('orlux/alerts');

  static Future<void> replaceAll(List<Map<String, dynamic>> events) async {
    try {
      await channel.invokeMethod<void>('replaceAll', events);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  static Future<void> snooze({
    required int id,
    required int minutes,
    required String title,
    required String body,
    required String payload,
    required bool needsCode,
  }) async {
    try {
      await channel.invokeMethod<void>('snooze', {
        'id': id,
        'minutes': minutes,
        'title': title,
        'body': body,
        'payload': payload,
        'needsCode': needsCode,
      });
    } catch (_) {}
  }

  static Future<String?> takePending() async {
    try {
      return await channel.invokeMethod<String>('takePending');
    } catch (_) {
      return null;
    }
  }

  static Future<void> requestBatteryExemption() async {
    try {
      await channel.invokeMethod<void>('requestBattery');
    } catch (_) {}
  }

  static Future<bool> isBatteryExempt() async {
    try {
      return await channel.invokeMethod<bool>('batteryExempt') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic>? decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
