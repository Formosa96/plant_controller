import 'package:flutter/material.dart';

class SensorInfo extends StatelessWidget {
  final int humidity;
  final int light;

  const SensorInfo({super.key, required this.humidity, required this.light});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Humidity: $humidity", style: const TextStyle(fontSize: 18)),
        Text("Light intensity: $light", style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}
