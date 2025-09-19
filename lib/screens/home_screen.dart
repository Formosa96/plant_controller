import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'remote_control_screen.dart';
import 'growth_cycle_screen.dart';
import 'package:plant_controller/bluetooth_connection/connector.dart';
import 'package:plant_controller/bluetooth_connection/device_controller.dart';

class HomeScreen extends StatefulWidget {
  final BluetoothDevice device;
  const HomeScreen({super.key, required this.device});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final int maxLength = 15;

  late final Connector _conn;
  late final DeviceController _ctrl;

  String _suffix = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final rawName = widget.device.name; // bywa puste/nieaktualne
    final parts = rawName.split('_');
    _suffix = parts.length > 1 ? parts.sublist(1).join('_') : '';
    _controller.text = _suffix;

    _conn = Connector();
    _ctrl = DeviceController(_conn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndApply() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      _msg('Enter a name (allowed: a-z, 0-9, _ and -, max 15)');
      return;
    }

    setState(() => _busy = true);
    try {
      await _conn.connectToDevice(widget.device);
      await _ctrl.setupCharacteristics(); // znajdzie 0007
      await _ctrl.renameGarden(raw);
      await _conn.disconnect(); // pozwól ESP wznowić reklamę z nową nazwą

      if (!mounted) return;
      _msg('Saved! Re-scan to see: garden_${raw.toLowerCase()}');
      Navigator.pop(context); // wróć do skanera
    } catch (e) {
      _msg('Rename failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _disconnectAndPop() async {
    try {
      await _conn.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fullName = 'garden_$_suffix';

    return WillPopScope(
      onWillPop: () async {
        await _disconnectAndPop();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFA7DB8D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Disconnect',
              icon: const Icon(Icons.logout),
              onPressed: _busy ? null : _disconnectAndPop,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLength: maxLength,
                decoration: InputDecoration(
                  hintText: 'Change device suffix (e.g. mojanazwa)',
                  helperText: 'Allowed: letters, numbers, _ and - (max 15)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
                onChanged: (v) => setState(() => _suffix = v.trim()),
                onSubmitted: (_) => _saveAndApply(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: _busy
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text('Save & Apply'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF63A46C)),
                  onPressed: _busy ? null : _saveAndApply,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF63A46C),
                  minimumSize: const Size.fromHeight(100),
                ),
                onPressed: _busy
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RemoteControl(device: widget.device)),
                  );
                },
                child: const Text('Remote control', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF63A46C),
                  minimumSize: const Size.fromHeight(100),
                ),
                onPressed: _busy
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GrowthCyclePage(device: widget.device)),
                  );
                },
                child: const Text('Growth cycle', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
