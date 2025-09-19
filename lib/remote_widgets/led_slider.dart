import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class LedSlider extends StatelessWidget {
  final int brightness;
  final ValueChanged<int> onChanged;
  final BluetoothCharacteristic? ledChar;

  const LedSlider({
    super.key,
    required this.brightness,
    required this.onChanged,
    required this.ledChar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("LED brightness: $brightness", style: const TextStyle(fontSize: 16)),
        Slider(
          value: brightness.toDouble(),
          min: 0,
          max: 255,
          divisions: 255,
          label: "$brightness",
          onChanged: (val) async {
            int level = val.toInt();
            onChanged(level);
            if (ledChar != null) {
              await ledChar!.write([level]);
            }
          },
        ),
      ],
    );
  }
}
