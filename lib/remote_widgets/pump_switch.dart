import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PumpSwitch extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool> onChanged;
  final BluetoothCharacteristic? pumpChar;

  const PumpSwitch({
    super.key,
    required this.isOn,
    required this.onChanged,
    required this.pumpChar,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text("Water pump"),
      value: isOn,
      onChanged: (val) async {
        onChanged(val);
        if (pumpChar != null) {
          await pumpChar!.write([val ? 1 : 0]);
        }
      },
    );
  }
}
