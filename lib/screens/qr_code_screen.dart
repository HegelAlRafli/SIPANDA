import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeScreen extends StatelessWidget {
  final String? qrData;
  const QRCodeScreen({super.key, this.qrData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Anda')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    if (qrData != null)
                      QrImageView(
                        data: qrData!,
                        version: QrVersions.auto,
                        size: 250.0,
                      )
                    else
                      const Text('Data QR tidak ditemukan.'),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                _buildActionButton(context,
                    icon: Icons.download,
                    text: 'Download QR',
                    onPressed: () {}),
                const SizedBox(height: 16),
                _buildActionButton(context,
                    icon: Icons.share, text: 'Share QR', onPressed: () {}),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide.none,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999)),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Data Telah Disimpan'),
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      required String text,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56)),
      icon: Icon(icon),
      label: Text(text),
      onPressed: onPressed,
    );
  }
}
