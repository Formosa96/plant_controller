import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'network_config.dart';
import 'home_screen.dart';

class DeviceOptionsSheet extends StatelessWidget {
  final BluetoothDevice device;

  const DeviceOptionsSheet({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                MaterialPageRoute(builder: (_) => NetworkConfigPage(device: device)),
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
                MaterialPageRoute(builder: (_) => HomeScreen(device: device)),
              );
            },
          ),
        ],
      ),
    );
  }
}
