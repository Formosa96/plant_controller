import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DashboardPage extends StatefulWidget {
  final BluetoothDevice device;

  const DashboardPage({Key? key, required this.device}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Guid serviceUuid = Guid("12340000-0000-1000-8000-00805f9b34fb");
  final Guid humidityUuid = Guid("12340001-0000-1000-8000-00805f9b34fb");
  final Guid lightUuid = Guid("12340002-0000-1000-8000-00805f9b34fb");
  final Guid ledUuid = Guid("12340003-0000-1000-8000-00805f9b34fb");
  final Guid pumpUuid = Guid("12340004-0000-1000-8000-00805f9b34fb");

  BluetoothCharacteristic? humidityChar;
  BluetoothCharacteristic? lightChar;
  BluetoothCharacteristic? ledChar;
  BluetoothCharacteristic? pumpChar;

  int humidity = 0;
  int light = 0;
  int ledBrightness = 0;
  bool pumpOn = false;
  bool connected = false;
  bool connecting = true;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
    } catch (_) {}

    List<BluetoothService> services = await widget.device.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var char in service.characteristics) {
          if (char.uuid == humidityUuid) humidityChar = char;
          if (char.uuid == lightUuid) lightChar = char;
          if (char.uuid == ledUuid) ledChar = char;
          if (char.uuid == pumpUuid) pumpChar = char;
        }
      }
    }

    if (humidityChar != null) {
      await humidityChar!.setNotifyValue(true);
      humidityChar!.lastValueStream.listen((value) {
        if (value.length >= 2) {
          int val = value[0] | (value[1] << 8);
          setState(() => humidity = val);
        }
      });
    }

    if (lightChar != null) {
      await lightChar!.setNotifyValue(true);
      lightChar!.lastValueStream.listen((value) {
        if (value.length >= 2) {
          int val = value[0] | (value[1] << 8);
          setState(() => light = val);
        }
      });
    }

    if (ledChar != null) {
      final val = await ledChar!.read();
      if (val.isNotEmpty) ledBrightness = val[0];
    }
    if (pumpChar != null) {
      final val = await pumpChar!.read();
      if (val.isNotEmpty) pumpOn = val[0] != 0;
    }

    setState(() {
      connecting = false;
      connected = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (connecting) {
      return Scaffold(
        appBar: AppBar(title: const Text("Connecting")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!connected) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Device not found")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Humidity: $humidity", style: const TextStyle(fontSize: 18)),
            Text("Light intensity: $light", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text("LED brightness: $ledBrightness", style: const TextStyle(fontSize: 16)),
            Slider(
              value: ledBrightness.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              label: "$ledBrightness",
              onChanged: (val) async {
                int level = val.toInt();
                setState(() => ledBrightness = level);
                if (ledChar != null) {
                  await ledChar!.write([level]);
                }
              },
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("Water pump"),
              value: pumpOn,
              onChanged: (val) async {
                setState(() => pumpOn = val);
                if (pumpChar != null) {
                  await pumpChar!.write([val ? 1 : 0]);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
