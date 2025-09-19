import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'connector.dart';

class DeviceController {
  final Connector connector;

  BluetoothCharacteristic? humidityChar; // 0001 (notify, read)
  BluetoothCharacteristic? lightChar;    // 0002 (notify, read)
  BluetoothCharacteristic? ledChar;      // 0003 (read, write)
  BluetoothCharacteristic? pumpChar;     // 0004 (read, write)
  BluetoothCharacteristic? nameChar;     // 0007 (read, write)

  DeviceController(this.connector);

  // Używamy Guid – zero kłopotów z formatem/case
  static final Guid _UUID_HUMIDITY = Guid('12340001-0000-1000-8000-00805f9b34fb');
  static final Guid _UUID_LIGHT    = Guid('12340002-0000-1000-8000-00805f9b34fb');
  static final Guid _UUID_LED      = Guid('12340003-0000-1000-8000-00805f9b34fb');
  static final Guid _UUID_PUMP     = Guid('12340004-0000-1000-8000-00805f9b34fb');
  static final Guid _UUID_NAME     = Guid('12340007-0000-1000-8000-00805f9b34fb');

  Future<void> setupCharacteristics() async {
    // 1st discover
    var services = await connector.discoverServices();
    if (!_pickChars(services)) {
      // fallback: dobij cache i powtórz
      try { await connector.device.clearGattCache(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
      services = await connector.discoverServices();
      if (!_pickChars(services)) {
        // debug dump co apka REALNIE widzi
        for (final s in services) {
          debugPrint('[BLE] Service: ${s.uuid}');
          for (final c in s.characteristics) {
            debugPrint('  └─ ${c.uuid}  props: r=${c.properties.read} '
                'w=${c.properties.write} wnr=${c.properties.writeWithoutResponse} '
                'n=${c.properties.notify}');
          }
        }
        throw StateError('Rename characteristic not found (${_UUID_NAME.str}).');
      }
    }
  }

  bool _pickChars(List<BluetoothService> services) {
    humidityChar = null;
    lightChar = null;
    ledChar = null;
    pumpChar = null;
    nameChar = null;

    for (final s in services) {
      for (final c in s.characteristics) {
        final id = c.uuid;
        if (id == _UUID_HUMIDITY) {
          humidityChar = c;
        } else if (id == _UUID_LIGHT) {
          lightChar = c;
        } else if (id == _UUID_LED) {
          ledChar = c;
        } else if (id == _UUID_PUMP) {
          pumpChar = c;
        } else if (id == _UUID_NAME) {
          nameChar = c;
        }
      }
    }

    // włącz notyfikacje na czujnikach, gdy są
    try { if (humidityChar != null) humidityChar!.setNotifyValue(true); } catch (_) {}
    try { if (lightChar != null)    lightChar!.setNotifyValue(true);    } catch (_) {}

    // do rename wymagamy 0007, reszta opcjonalna
    return nameChar != null;
  }

  // ====== Streams czujników (uint16 LE) ======
  Stream<int> humidityStream() {
    final c = humidityChar ?? (throw StateError('Humidity characteristic not ready'));
    return connector.subscribe(c).map(_toUint16LE);
  }

  Stream<int> lightStream() {
    final c = lightChar ?? (throw StateError('Light characteristic not ready'));
    return connector.subscribe(c).map(_toUint16LE);
  }

  int _toUint16LE(List<int> v) {
    if (v.length < 2) return 0;
    return (v[0] & 0xFF) | ((v[1] & 0xFF) << 8);
  }

  // ====== Sterowanie ======
  Future<void> setLed(int value) async {
    final c = ledChar ?? (throw StateError('LED characteristic not available'));
    final v = value.clamp(0, 255);
    await connector.sendCommand(c, [v]);
  }

  Future<void> setPump(bool on) async {
    final c = pumpChar ?? (throw StateError('PUMP characteristic not available'));
    await connector.sendCommand(c, [on ? 1 : 0]);
  }

  Future<void> renameGarden(String raw) async {
    final c = nameChar ?? (throw StateError('Rename characteristic not ready'));
    final s = _sanitize(raw);
    if (s.isEmpty) {
      throw ArgumentError('Invalid name: letters/numbers/_/- only (max 15).');
    }
    await connector.sendCommand(c, utf8.encode(s));
  }

  String _sanitize(String s) {
    final allowed = RegExp(r'[A-Za-z0-9_-]');
    final b = StringBuffer();
    for (final ch in s.trim().split('')) {
      if (allowed.hasMatch(ch)) b.write(ch.toLowerCase());
      else if (ch == ' ') b.write('_');
      if (b.length >= 15) break;
    }
    return b.toString();
  }
}
