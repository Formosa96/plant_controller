import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';

class GrowthCyclePage extends StatefulWidget {
  final BluetoothDevice device;

  const GrowthCyclePage({super.key, required this.device});

  @override
  State<GrowthCyclePage> createState() => _GrowthCyclePageState();
}

class _GrowthCyclePageState extends State<GrowthCyclePage> {
  final List<String> demandOptions = ['Low', 'Medium', 'High'];

  String lightDemand = 'High';
  String waterDemand = 'High';

  final TextEditingController nameController = TextEditingController(text: 'Basil');
  final TextEditingController lightDurationController = TextEditingController(text: '13');

  @override
  void dispose() {
    nameController.dispose();
    lightDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA7DB8D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Enter plant name",
              ),
            ),
            const SizedBox(height: 16),
            const Text('Daily light time:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: TextField(
                controller: lightDurationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF63A46C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixText: 'h',
                  suffixStyle: const TextStyle(color: Colors.white),
                ),
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),

            const SizedBox(height: 16),
            const Text('Light demand:', style: TextStyle(fontSize: 16)),
            DropdownButton<String>(
              value: lightDemand,
              onChanged: (value) => setState(() => lightDemand = value!),
              items: demandOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Water demand:', style: TextStyle(fontSize: 16)),
            DropdownButton<String>(
              value: waterDemand,
              onChanged: (value) => setState(() => waterDemand = value!),
              items: demandOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      spots: const [],
                      isStrokeCapRound: true,
                      color: Colors.red,
                      barWidth: 2,
                    ),
                  ],
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
