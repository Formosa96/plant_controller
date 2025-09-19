import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Connector {
  BluetoothDevice? _device;

  Future<void> connectToDevice(BluetoothDevice device) async {
    _device = device;
    try { await device.disconnect(); } catch (_) {} // na wszelki wypadek

    try {
      await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
    } catch (_) {}

    try { await device.requestMtu(185); } catch (_) {}
    try { await device.clearGattCache(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> disconnect() async {
    try { await _device?.disconnect(); } catch (_) {}
  }

  Future<List<BluetoothService>> discoverServices() async {
    final d = _device;
    if (d == null) throw StateError('Device not connected');
    return d.discoverServices();
  }

  Stream<List<int>> subscribe(BluetoothCharacteristic c) {
    c.setNotifyValue(true);
    return c.lastValueStream;
  }

  Future<void> sendCommand(BluetoothCharacteristic c, List<int> value) async {
    final useNr = c.properties.writeWithoutResponse && !c.properties.write;
    await c.write(value, withoutResponse: useNr);
  }

  BluetoothDevice get device => _device!;
}
