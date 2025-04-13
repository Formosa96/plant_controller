import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DashboardPage extends StatefulWidget {
  final BluetoothDevice device;

  const DashboardPage({super.key, required this.device});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  BluetoothCharacteristic? ssidChar;
  BluetoothCharacteristic? passChar;

  String status = "Connecting";

  @override
  void initState() {
    super.initState();
    connectAndDiscover();
  }

  Future<void> connectAndDiscover() async {
    try {
      print("Connection attempt");
      await widget.device.connect(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 2));

      setState(() => status = "Connected with ${widget.device.platformName}");
      print("Connected with ${widget.device.platformName}");

      List<BluetoothService> services = await widget.device.discoverServices();
      print("BLT services:");

      for (var service in services) {
        print(" Service UUID: ${service.uuid}");
        for (var char in service.characteristics) {
          print("   Characteristic UUID: ${char.uuid}");

          final charUuid = char.uuid.toString().toLowerCase();
          if (charUuid.contains("abcd1234")) {
            ssidChar = char;
            print("Found SSID characteristic");
          } else if (charUuid.contains("abcd1235")) {
            passChar = char;
            print("Foun password characteristic");
          }
        }
      }

      if (ssidChar != null && passChar != null) {
        setState(() {
          status = "Ready for Wi-Fi config";
        });
      } else {
        setState(() {
          status = "Wi-Fi characteristics not found";
        });
      }
    } catch (e) {
      setState(() => status = "Error: $e");
      print("Connection or discoverServices error: $e");
    }
  }

  Future<void> sendWifiCredentials() async {
    if (ssidChar == null || passChar == null) return;

    await ssidChar!.write(ssidController.text.codeUnits); // 👈 ważne: bez `withoutResponse`
    await passChar!.write(passwordController.text.codeUnits);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Wi-Fi data send to garden")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device.platformName)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(labelText: "SSID Wi-Fi"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password Wi-Fi"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendWifiCredentials,
              child: const Text("Send data to garden"),
            ),
          ],
        ),
      ),
    );
  }
}
