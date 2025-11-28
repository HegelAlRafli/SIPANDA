import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as developer;

import 'package:myapp/models/dynamic_field_model.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});
  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaBarangController = TextEditingController();
  final _kategoriBarangController = TextEditingController();
  final List<DynamicFieldControllers> _dynamicFieldControllers = [];

  XFile? _imageFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _namaBarangController.dispose();
    _kategoriBarangController.dispose();
    for (var controllerPair in _dynamicFieldControllers) {
      controllerPair.keyController.dispose();
      controllerPair.valueController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      setState(() {
        _imageFile = pickedFile;
      });
    } catch (e) {
      developer.log("Image picking failed: $e", name: "AddItemScreen");
    }
  }

  void _addDynamicField() {
    setState(() {
      _dynamicFieldControllers.add(DynamicFieldControllers());
    });
  }

  void _removeDynamicField(int index) {
    setState(() {
      _dynamicFieldControllers[index].keyController.dispose();
      _dynamicFieldControllers[index].valueController.dispose();
      _dynamicFieldControllers.removeAt(index);
    });
  }

  Future<String?> _uploadImage(String itemId) async {
    if (_imageFile == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('item_images')
          .child('$itemId.jpg');
      await ref.putFile(File(_imageFile!.path));
      return await ref.getDownloadURL();
    } catch (e) {
      developer.log("Image upload failed: $e", name: "AddItemScreen");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengunggah gambar: $e")),
      );
      return null;
    }
  }

  void _generateQRCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      final docRef = FirebaseFirestore.instance.collection('items').doc();
      String? imageUrl;

      if (_imageFile != null) {
        imageUrl = await _uploadImage(docRef.id);
        if (imageUrl == null) {
          setState(() {
            _isUploading = false;
          });
          return; // Stop if image upload fails
        }
      }

      Map<String, dynamic> data = {
        'id': docRef.id,
        'namaBarang': _namaBarangController.text,
        'kategoriBarang': _kategoriBarangController.text,
        'imageUrl': imageUrl,
        'details': _dynamicFieldControllers
            .map((controllers) => {
                  'key': controllers.keyController.text,
                  'value': controllers.valueController.text,
                })
            .where((field) => field['key']!.isNotEmpty)
            .toList(),
      };

      // Save data first
      await docRef.set(data).then((_) {
        // Navigate on success
        context.goNamed('qr_code', extra: docRef.id);
      }).catchError((error) {
        developer.log("Failed to save data: $error", name: "AddItemScreen");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan data: $error")),
        );
      }).whenComplete(() {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Data Barang Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildImagePicker(),
            const SizedBox(height: 24),
            _buildTextField(
                _namaBarangController, 'Nama Barang', 'Masukkan nama barang'),
            const SizedBox(height: 16),
            _buildTextField(
                _kategoriBarangController, 'Kategori Barang', 'Pilih Kategori'),
            const SizedBox(height: 24),
            Text("Detail Tambahan",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._buildDynamicFields(),
            const SizedBox(height: 16),
            _buildAddNewFieldButton(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isUploading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                onPressed: _generateQRCode,
                child: const Text('Generate QR Code'),
              ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 150,
          width: 150,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[400]!, width: 2),
          ),
          child: _imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(_imageFile!.path),
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.grey[600], size: 40),
                    const SizedBox(height: 8),
                    Text("Pilih Gambar",
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicFields() {
    return _dynamicFieldControllers.asMap().entries.map((entry) {
      int index = entry.key;
      var controllers = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Expanded(
                child: _buildTextField(
                    controllers.keyController, 'Contoh: Warna', 'Key')),
            const SizedBox(width: 16),
            Expanded(
                child: _buildTextField(
                    controllers.valueController, 'Contoh: Merah', 'Value')),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeDynamicField(index),
            )
          ],
        ),
      );
    }).toList();
  }

  Widget _buildAddNewFieldButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(
            width: 2,
            style: BorderStyle.solid,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.add_circle),
      label: const Text('Tambah Field Baru'),
      onPressed: _addDynamicField,
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String hint) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (controller == _namaBarangController ||
            controller == _kategoriBarangController) {
          if (value == null || value.isEmpty) {
            return '$label tidak boleh kosong';
          }
        }
        return null;
      },
    );
  }
}
