import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'dart:developer' as developer;

class QrCodeScreen extends StatelessWidget {
  final String itemId;
  final GlobalKey _qrKey = GlobalKey();

  QrCodeScreen({super.key, required this.itemId});

  // REWRITTEN AND SIMPLIFIED DOWNLOAD LOGIC
  Future<void> _downloadQrCode(BuildContext context) async {
    try {
      // 1. Find the QR code widget boundary
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // 2. Convert it to an image
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      // 3. Check if conversion was successful
      if (byteData == null) {
        throw Exception("Gagal mengonversi QR code menjadi data gambar.");
      }
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 4. Save the file
      await FileSaver.instance.saveAs(
        name: 'qr_code_$itemId',
        bytes: pngBytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );

      // 5. Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code berhasil diunduh.')),
        );
      }
    } catch (e, s) {
      // CATCH-ALL: Log the full error to the debug console
      developer.log(
        'Error downloading QR Code',
        error: e,
        stackTrace: s,
        name: 'QrCodeScreen',
      );

      // Show a user-friendly error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Pindai kode ini untuk melihat detail barang',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                child: QrImageView(
                  data: itemId,
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download QR'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: () => _downloadQrCode(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
