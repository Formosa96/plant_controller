import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dashboard.dart';
import 'network_config.dart';

class BleScannerPage extends StatefulWidget {
  const BleScannerPage({super.key});

  @override
  State<BleScannerPage> createState() => _BleScannerPageState();
}

class _BleScannerPageState extends State<BleScannerPage> {
  List<ScanResult> results = [];

  @override
  void initState() {
    super.initState();
    startBLEScan();
  }

  Future<void> startBLEScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((r) {
      setState(() {
        results = r
            .where((res) => res.device.platformName.contains("garden"))
            .toList();
      });
    });
  }



  void _showDeviceOptions(BluetoothDevice device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('Config network'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NetworkConfigPage(device: device),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('BT pilot'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardPage(device: device),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose garden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                results.clear();
              });
              startBLEScan();
            },
          ),
        ],
      ),
      body: results.isEmpty
          ? const Center(child: Text("Scanning"))
          : ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final device = results[index].device;
          return ListTile(
            title: Text(device.platformName),
            subtitle: Text(device.remoteId.toString()),
            trailing: const Icon(Icons.bluetooth),
            onTap: () => _showDeviceOptions(device),
          );
        },
      ),
    );
  }
}
