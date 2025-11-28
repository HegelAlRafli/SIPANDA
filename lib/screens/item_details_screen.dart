import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ItemDetailsScreen extends StatefulWidget {
  final String itemId;
  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  Future<void> _deleteItem(BuildContext context, String imageUrl) async {
    try {
      // 1. Delete image from Storage
      if (imageUrl.isNotEmpty) {
        final imageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        await imageRef.delete();
      }

      // 2. Delete document from Firestore
      await FirebaseFirestore.instance.collection('items').doc(widget.itemId).delete();

      if (!mounted) return; // Check if the widget is still in the tree

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang berhasil dihapus')),
      );

      // 3. Navigate back
      context.go('/item_list');
    } catch (e) {
      if (!mounted) return; // Check if the widget is still in the tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus barang: $e')),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, String imageUrl) {
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
                Navigator.of(dialogContext).pop(); // Close the dialog
                _deleteItem(context, imageUrl);
              },
            ),
          ],
        );
      },
    );
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
              // Fetch the image URL before showing the dialog
              FirebaseFirestore.instance
                  .collection('items')
                  .doc(widget.itemId)
                  .get()
                  .then((doc) {
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'] as String? ?? '';
                   if (mounted) {
                     _showDeleteConfirmationDialog(context, imageUrl);
                   }
                }
              });
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                if (imageUrl != null)
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
                            child: Icon(Icons.broken_image,
                                size: 48, color: Colors.grey));
                      },
                    ),
                  ),
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
                // --- QR CODE SECTION ---
                Center(
                  child: QrImageView(
                    data: widget.itemId, // The QR code data is the item ID itself
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Ambil screenshot untuk menyimpan atau membagikan QR Code ini.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ),
                // --- END QR CODE SECTION ---
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
}
