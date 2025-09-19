import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_tile.dart';
import 'device_options_sheet.dart';

class BleScannerPage extends StatefulWidget {
  const BleScannerPage({super.key});

  @override
  State<BleScannerPage> createState() => _BleScannerPageState();
}

class _BleScannerPageState extends State<BleScannerPage> {
  // NOWY UUID z ESP32
  final Guid _targetService = Guid('1234aa00-0000-1000-8000-00805f9b34fb');

  List<ScanResult> results = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;

  bool _scanning = false;
  bool _debugShowAll = false; // przełącznik w menu

  @override
  void initState() {
    super.initState();
    _bindIsScanning();
    startBLEScan();
  }

  void _bindIsScanning() {
    _isScanningSub?.cancel();
    _isScanningSub = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => _scanning = s);
    });
  }

  Future<void> startBLEScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      final map = <String, ScanResult>{};
      for (final r in list) {
        final adv = r.advertisementData;
        final advName = adv.advName;
        final plat = r.device.platformName;
        final name = (advName.isNotEmpty ? advName : plat).toLowerCase();

        final hasService = adv.serviceUuids.contains(_targetService);

        if (_debugShowAll || name.startsWith('garden_') || hasService) {
          map[r.device.remoteId.str] = r;
        }
      }
      if (mounted) setState(() => results = map.values.toList());
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 6),
      androidScanMode: AndroidScanMode.lowLatency,
      // nie stosuj withServices – część telefonów filtruje za agresywnie
    );
  }

  Future<void> stopBLEScan() async => FlutterBluePlus.stopScan();

  void _showDeviceOptions(BluetoothDevice device) {
    showModalBottomSheet(
      context: context,
      builder: (_) => DeviceOptionsSheet(device: device),
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA7DB8D),
      appBar: AppBar(
        title: const Text('Choose garden'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _scanning ? 'Stop scan' : 'Scan',
            icon: Icon(_scanning ? Icons.stop : Icons.refresh),
            onPressed: () async {
              setState(() => results.clear());
              if (_scanning) await stopBLEScan(); else await startBLEScan();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'toggle_debug') {
                setState(() => _debugShowAll = !_debugShowAll);
                await stopBLEScan();
                setState(() => results.clear());
                await startBLEScan();
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'toggle_debug',
                checked: _debugShowAll,
                child: const Text('Show all (debug)'),
              ),
            ],
          ),
        ],
      ),
      body: _scanning && results.isEmpty
          ? const Center(child: Text("Scanning..."))
          : (results.isEmpty
          ? const Center(child: Text("No devices found"))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final res = results[index];
          final device = res.device;
          final adv = res.advertisementData;
          final name = adv.advName.isNotEmpty
              ? adv.advName
              : (device.platformName.isNotEmpty
              ? device.platformName
              : device.remoteId.str);

          return DeviceTile(
            device: device,
            titleOverride: name,
            onTap: () => _showDeviceOptions(device),
          );
        },
      )),
    );
  }
}
