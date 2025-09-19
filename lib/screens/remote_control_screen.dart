import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:plant_controller/remote_widgets/sensor_info.dart';
// import 'package:plant_controller/remote_widgets/led_slider.dart'; // nie używamy teraz
import 'package:plant_controller/remote_widgets/pump_switch.dart';
import 'ble_scanner.dart';

class RemoteControl extends StatefulWidget {
  final BluetoothDevice device;

  const RemoteControl({Key? key, required this.device}) : super(key: key);

  @override
  State<RemoteControl> createState() => _RemoteControlState();
}

class _RemoteControlState extends State<RemoteControl> {
  // ===== UUIDy
  final Guid humidityUuid = Guid("12340001-0000-1000-8000-00805f9b34fb");
  final Guid lightUuid    = Guid("12340002-0000-1000-8000-00805f9b34fb");
  final Guid ledUuid      = Guid("12340003-0000-1000-8000-00805f9b34fb");
  final Guid pumpUuid     = Guid("12340004-0000-1000-8000-00805f9b34fb");

  BluetoothCharacteristic? humidityChar;
  BluetoothCharacteristic? lightChar;
  BluetoothCharacteristic? ledChar;
  BluetoothCharacteristic? pumpChar;

  StreamSubscription<List<int>>? _humSub;
  StreamSubscription<List<int>>? _luxSub;

  // ===== stany surowe z BLE
  int _humidityAdc = 0;       // 0..4095 (im wyżej tym bardziej sucho)
  int _lightLuxInt = 0;       // 0..65535 (BH1750 → lx)
  int _ledRaw255   = 0;       // 0..255
  bool pumpOn = false;

  // ===== stany przetworzone do UI
  int humidityPct = 0;        // 0..100 (%)
  int lightPctLog = 0;        // 0..100 (% log)
  double lightLux = 0;        // lux (double do UI)
  int ledPct      = 0;        // 0..100 (%)

  bool connected = false;
  bool connecting = true;

  // ===== kalibracje / skalowanie
  // Wilgotność (ADC): im wyżej, tym sucho. Zmienisz po kalibracji.
  int adcDry  = 4095; // „sucho”
  int adcWet  = 900;  // „mokro” (Twój odczyt w wodzie)

  // Skala logarytmiczna lux → %
  static const double L_MIN = 50.0;    // poniżej – traktujemy jako ciemność
  static const double L_MAX = 65000.0; // praktyczny zakres BH1750/uint16

  // info o ostatnim błędzie zapisu LED (do debug UI)
  String? _ledWriteError;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  @override
  void dispose() {
    _humSub?.cancel();
    _luxSub?.cancel();
    () async { try { await widget.device.disconnect(); } catch (_) {} }();
    super.dispose();
  }

  // ===== HELPERY PRZELICZENIOWE =====
  int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  int _mapHumidityAdcToPct(int adc) {
    // moisture_% = 100 * (ADC_dry - ADC) / (ADC_dry - ADC_wet)
    final denom = (adcDry - adcWet).toDouble();
    if (denom.abs() < 1e-6) return 0;
    final pct = 100.0 * (adcDry - adc) / denom;
    return _clampInt(pct.round(), 0, 100);
  }

  int _luxToPctLog(double lux) {
    final lx = lux <= 1 ? 1.0 : lux; // avoid log(0)
    final num = math.log(lx.clamp(L_MIN, L_MAX)) / math.ln10 - math.log(L_MIN) / math.ln10;
    final den = math.log(L_MAX) / math.ln10 - math.log(L_MIN) / math.ln10;
    final pct = 100.0 * (num / den);
    return _clampInt(pct.round(), 0, 100);
  }

  int _toUint16LE(List<int> v) {
    if (v.length < 2) return 0;
    return (v[0] & 0xFF) | ((v[1] & 0xFF) << 8);
  }

  int _byteToPct(int b0_255) => _clampInt(((b0_255 / 255.0) * 100.0).round(), 0, 100);
  int _pctToByte(int pct0_100) => _clampInt(((pct0_100.clamp(0, 100) / 100.0) * 255.0).round(), 0, 255);

  Future<void> _writeLedPct(int pct) async {
    if (ledChar == null) return;
    final b = _pctToByte(pct);
    try {
      // Firmware ma PROPERTY_WRITE → piszemy Z ODPOWIEDZIĄ
      await ledChar!.write([b], withoutResponse: false);
      final echoed = await ledChar!.read(); // potwierdzenie
      if (echoed.isNotEmpty) {
        setState(() {
          _ledWriteError = null;
          _ledRaw255 = echoed[0];
          ledPct = _byteToPct(_ledRaw255);
        });
      }
    } catch (e) {
      // awaryjna próba bez odpowiedzi
      try { await ledChar!.write([b], withoutResponse: true); } catch (_) {}
      setState(() => _ledWriteError = "LED write failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_ledWriteError!)),
        );
      }
    }
  }

  // ====== BLE ======
  Future<void> connectToDevice() async {
    try { await widget.device.disconnect(); } catch (_) {}
    try { await widget.device.connect(timeout: const Duration(seconds: 10), autoConnect: false); } catch (_) {}

    try { await widget.device.requestMtu(185); } catch (_) {}
    try { await widget.device.clearGattCache(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));

    var services = await widget.device.discoverServices();
    if (!_pickChars(services)) {
      try { await widget.device.clearGattCache(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
      services = await widget.device.discoverServices();
      _pickChars(services);
    }

    // Subskrypcje czujników
    if (humidityChar != null) {
      try { await humidityChar!.setNotifyValue(true); } catch (_) {}
      _humSub = humidityChar!.lastValueStream.listen((value) {
        final adc = _toUint16LE(value);
        setState(() {
          _humidityAdc = adc;
          humidityPct = _mapHumidityAdcToPct(adc);
        });
      });
    }
    if (lightChar != null) {
      try { await lightChar!.setNotifyValue(true); } catch (_) {}
      _luxSub = lightChar!.lastValueStream.listen((value) {
        final luxInt = _toUint16LE(value);        // ESP wysyła już lx jako uint16 LE
        final lux = luxInt.toDouble();
        setState(() {
          _lightLuxInt = luxInt;
          lightLux = lux;
          lightPctLog = _luxToPctLog(lux);
        });
      });
    }

    // Stany początkowe LED/PUMP
    if (ledChar != null) {
      try {
        final val = await ledChar!.read(); // 0..255 z firmware
        if (val.isNotEmpty) {
          _ledRaw255 = val[0];
          ledPct = _byteToPct(_ledRaw255);
        }
      } catch (_) {}
    }
    if (pumpChar != null) {
      try {
        final val = await pumpChar!.read();
        if (val.isNotEmpty) pumpOn = val[0] != 0;
      } catch (_) {}
    }

    setState(() {
      connecting = false;
      connected = true;
    });
  }

  bool _pickChars(List<BluetoothService> services) {
    humidityChar = null; lightChar = null; ledChar = null; pumpChar = null;
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid == humidityUuid)      { humidityChar = c; }
        else if (c.uuid == lightUuid)    { lightChar    = c; }
        else if (c.uuid == ledUuid)      { ledChar      = c; }
        else if (c.uuid == pumpUuid)     { pumpChar     = c; }
      }
    }
    return humidityChar != null || lightChar != null || ledChar != null || pumpChar != null;
  }

  @override
  Widget build(BuildContext context) {
    if (connecting) {
      return const Scaffold(
        backgroundColor: Color(0xFFA7DB8D),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!connected) {
      return const Scaffold(
        backgroundColor: Color(0xFFA7DB8D),
        body: Center(child: Text("Device not found")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFA7DB8D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AppBar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BleScannerPage()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),


              const SizedBox(height: 8),
              _InfoLine(label: "Humidity", value: "$humidityPct%", secondary: "ADC: $_humidityAdc"),
              _InfoLine(label: "Light", value: "$lightPctLog%", secondary: "${lightLux.toStringAsFixed(0)} lx"),

              const SizedBox(height: 20),

              // LED: UI 0–100, zapis 0–255
              _LedPercentControl(
                valuePct: ledPct,
                onChangedPct: (v) async {
                  setState(() => ledPct = v);
                  await _writeLedPct(v);
                },
              ),


              const SizedBox(height: 20),

              PumpSwitch(
                isOn: pumpOn,
                onChanged: (val) => setState(() => pumpOn = val),
                pumpChar: pumpChar,
              ),

              if (humidityChar == null || lightChar == null || ledChar == null || pumpChar == null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    "Not all characteristics found. Make sure firmware exposes 0001/0002/0003/0004.",
                    style: TextStyle(fontSize: 12),
                  ),
                ),

              const Spacer(),

              _CalibrationHint(
                adcDry: adcDry,
                adcWet: adcWet,
                onApply: (dry, wet) {
                  setState(() {
                    adcDry = dry;
                    adcWet = wet;
                    humidityPct = _mapHumidityAdcToPct(_humidityAdc);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Widżety pomocnicze =====
class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final String? secondary;
  const _InfoLine({required this.label, required this.value, this.secondary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        if (secondary != null) ...[
          const SizedBox(width: 8),
          Text("($secondary)", style: const TextStyle(color: Colors.black54)),
        ]
      ],
    );
  }
}

class _LedPercentControl extends StatelessWidget {
  final int valuePct; // 0..100
  final ValueChanged<int> onChangedPct;
  const _LedPercentControl({required this.valuePct, required this.onChangedPct});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LED Brightness", style: TextStyle(fontWeight: FontWeight.w600)),
        Row(
          children: [
            Expanded(
              child: Slider(
                min: 0,
                max: 100,
                divisions: 100,
                value: valuePct.toDouble(),
                onChanged: (v) => onChangedPct(v.round()),
              ),
            ),
            SizedBox(width: 48, child: Text("${valuePct}%", textAlign: TextAlign.right)),
          ],
        ),
      ],
    );
  }
}

class _CalibrationHint extends StatefulWidget {
  final int adcDry;
  final int adcWet;
  final void Function(int dry, int wet) onApply;
  const _CalibrationHint({required this.adcDry, required this.adcWet, required this.onApply});

  @override
  State<_CalibrationHint> createState() => _CalibrationHintState();
}

class _CalibrationHintState extends State<_CalibrationHint> {
  late final TextEditingController dryC = TextEditingController(text: widget.adcDry.toString());
  late final TextEditingController wetC = TextEditingController(text: widget.adcWet.toString());

  @override
  void dispose() { dryC.dispose(); wetC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text("Calibration (temp): ADC dry/wet", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Row(
          children: [
            SizedBox(
              width: 90,
              child: TextField(controller: dryC, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, labelText: "ADC dry")),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: TextField(controller: wetC, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, labelText: "ADC wet")),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                final d = int.tryParse(dryC.text) ?? widget.adcDry;
                final w = int.tryParse(wetC.text) ?? widget.adcWet;
                widget.onApply(d, w);
              },
              child: const Text("Apply"),
            )
          ],
        )
      ],
    );
  }
}
