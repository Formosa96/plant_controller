import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onTap;
  final String? titleOverride;

  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.titleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (titleOverride != null && titleOverride!.trim().isNotEmpty)
        ? titleOverride!.trim()
        : (device.platformName.isNotEmpty ? device.platformName : device.remoteId.str);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF63A46C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, color: Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
