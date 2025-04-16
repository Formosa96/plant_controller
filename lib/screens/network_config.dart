import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class NetworkConfigPage extends StatefulWidget {
  final BluetoothDevice device;

  const NetworkConfigPage({super.key, required this.device});

  @override
  State<NetworkConfigPage> createState() => _NetworkConfigPageState();
}

class _NetworkConfigPageState extends State<NetworkConfigPage> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  BluetoothCharacteristic? ssidChar;
  BluetoothCharacteristic? passChar;
  String status = "Connecting";

  final serviceUuid = Guid("12340000-0000-1000-8000-00805f9b34fb");
  final ssidUuid = Guid("12340005-0000-1000-8000-00805f9b34fb");
  final passUuid = Guid("12340006-0000-1000-8000-00805f9b34fb");

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }



  Future<void> connectToDevice() async {
    try {
      await widget.device.connect(autoConnect: false);
      List<BluetoothService> services = await widget.device.discoverServices();

      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid == ssidUuid) {
              ssidChar = char;
            } else if (char.uuid == passUuid) {
              passChar = char;
            }
          }
        }
      }

      if (ssidChar != null && passChar != null) {
        setState(() => status = "Ready to config");
      } else {
        setState(() => status = "Characteristics not found");
      }
    } catch (e) {
      setState(() => status = "Connection error: $e");
    }
  }



  Future<void> sendCredentials() async {
    if (ssidChar == null || passChar == null) return;

    await ssidChar!.write(ssidController.text.codeUnits);
    await passChar!.write(passwordController.text.codeUnits);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Wifi data sent to ESP")),
    );
  }



  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wifi configuration")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(labelText: "SSID"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendCredentials,
              child: const Text("Connect garden to Wi-Fi"),
            ),
          ],
        ),
      ),
    );
  }
}
