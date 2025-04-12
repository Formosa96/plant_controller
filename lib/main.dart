import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterBluePlus.setLogLevel(LogLevel.verbose);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 BLE Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const BleScannerPage(),
    );
  }
}

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
    // 📲 Prośba o uprawnienia
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // 🔍 Rozpoczęcie skanowania
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // 🎯 Nasłuchiwanie wyników
    FlutterBluePlus.scanResults.listen((r) {
      setState(() {
        results = r;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE – Wybierz urządzenie'),
      ),
      body: results.isEmpty
          ? const Center(child: Text("Skanuję... 🛰️"))
          : ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final device = results[index].device;
          return ListTile(
            title: Text(device.platformName.isNotEmpty
                ? device.platformName
                : "(Brak nazwy)"),
            subtitle: Text(device.remoteId.toString()),
            trailing: const Icon(Icons.bluetooth),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardPage(device: device),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
