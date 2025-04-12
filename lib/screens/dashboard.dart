import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DashboardPage extends StatefulWidget {
  final BluetoothDevice device;

  const DashboardPage({super.key, required this.device});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isConnecting = true;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect(timeout: const Duration(seconds: 10));
      print("✅ Połączono z: ${widget.device.platformName}");
    } catch (e) {
      print("❌ Błąd połączenia: $e");
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
      ),
      body: Center(
        child: isConnecting
            ? const CircularProgressIndicator()
            : const Text("Połączono! Tu będzie dashboard 🌱"),
      ),
    );
  }
}
