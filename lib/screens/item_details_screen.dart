
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ItemDetailsScreen extends StatefulWidget {
  final String itemId;
  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _deleteItem(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('items').doc(widget.itemId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang berhasil dihapus')),
      );

      context.go('/item_list');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus barang: $e')),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Barang'),
          content: const Text('Apakah Anda yakin ingin menghapus barang ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteItem(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadQrCode() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Kode QR untuk ${widget.itemId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh Kode QR: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Barang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.goNamed('edit_item', pathParameters: {'itemId': widget.itemId});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _showDeleteConfirmationDialog(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('items').doc(widget.itemId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Terjadi kesalahan"));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Barang tidak ditemukan"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final details = data['details'] as List<dynamic>? ?? [];
          final imageUrl = data['imageUrl'] as String?;
          final pemegangBarang = data['pemegangBarang'] as List<dynamic>? ?? [];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.network(
                      imageUrl,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        return progress == null
                            ? child
                            : const SizedBox(
                                height: 250,
                                child:
                                    Center(child: CircularProgressIndicator()));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                            height: 250,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text("Gagal memuat gambar", style: TextStyle(color: Colors.grey))
                                ],
                              ),
                            ));
                      },
                    ),
                  ) else const SizedBox(height: 250, child: Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey))),
                const SizedBox(height: 24),
                Text(data['namaBarang'] ?? 'Tanpa Nama',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Informasi detail barang hasil pemindaian QR code.',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                const Divider(),
                _buildDetailRow('ID Barang', widget.itemId),
                _buildDetailRow('Nama Barang', data['namaBarang'] ?? '-'),
                _buildDetailRow(
                    'Kategori Barang', data['kategoriBarang'] ?? '-'),
                ...details.map((detail) {
                  final key = detail['key'] as String? ?? 'Error';
                  final value = detail['value'] as String? ?? '-';
                  return _buildDetailRow(key, value);
                }),
                const Divider(height: 32),
                // New Section for Pemegang Barang
                if (pemegangBarang.isNotEmpty)
                  ..._buildPemegangList(pemegangBarang),
                
                Center(
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: QrImageView(
                      data: widget.itemId,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Pindai QR Code ini untuk melihat detail barang.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Unduh Kode QR'),
                  onPressed: _downloadQrCode,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56)),
          onPressed: () => context.go('/scan_qr'),
          child: const Text('Pindai Lagi'),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

    List<Widget> _buildPemegangList(List<dynamic> pemegangBarang) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Daftar Pemegang Barang", 
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        ),
      ),
      ...pemegangBarang.map((pemegang) {
        final nama = pemegang['nama'] as String? ?? 'Nama tidak tersedia';
        final imageUrl = pemegang['imageUrl'] as String?;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                  ? NetworkImage(imageUrl)
                  : null,
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            title: Text(nama, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      }).toList(),
      const Divider(height: 32),
    ];
  }
}
