import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as developer;

import 'package:myapp/models/dynamic_field_model.dart';

// Helper class to hold controllers for a single "Pemegang Barang"
class _PemegangBarangControllers {
  final TextEditingController nameController = TextEditingController();
  XFile? imageFile;
  final GlobalKey key = GlobalKey(); // To maintain state in the list
}

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
  final List<_PemegangBarangControllers> _pemegangControllers = [];

  final String _imgbbApiKey = "062dd36a9ba0bd8ec04a44ecd3fe896b";

  XFile? _itemImageFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _namaBarangController.dispose();
    _kategoriBarangController.dispose();
    for (var controllerPair in _dynamicFieldControllers) {
      controllerPair.keyController.dispose();
      controllerPair.valueController.dispose();
    }
    for (var pemegang in _pemegangControllers) {
      pemegang.nameController.dispose();
    }
    super.dispose();
  }

  Future<XFile?> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      return pickedFile;
    } catch (e) {
      developer.log("Image picking failed: $e", name: "AddItemScreen");
      return null;
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

  void _addPemegangField() {
    setState(() {
      _pemegangControllers.add(_PemegangBarangControllers());
    });
  }

  void _removePemegangField(int index) {
    setState(() {
      _pemegangControllers[index].nameController.dispose();
      _pemegangControllers.removeAt(index);
    });
  }

  Future<String?> _uploadImageFile(XFile imageFile) async {
    var request = http.MultipartRequest(
        'POST', Uri.parse('https://api.imgbb.com/1/upload'));
    request.fields['key'] = _imgbbApiKey;
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final json = jsonDecode(respStr);
        String imageUrl = json['data']['url'];

        imageUrl = imageUrl.replaceFirst("i.ibb.co/", "i.ibb.co.com/");

        developer.log("Image uploaded to imgbb: $imageUrl", name: "Upload");
        return imageUrl;
      } else {
        final errorBody = await response.stream.bytesToString();
        developer.log(
            "Image upload failed with status ${response.statusCode}: $errorBody",
            name: "Upload");
        return null;
      }
    } catch (e) {
      developer.log("Image upload exception: $e", name: "Upload");
      return null;
    }
  }

  void _generateQRCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final docRef = FirebaseFirestore.instance.collection('items').doc();
    String? itemImageUrl;

    if (_itemImageFile != null) {
      itemImageUrl = await _uploadImageFile(_itemImageFile!);
      if (itemImageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal mengunggah gambar utama.")),
          );
        }
        setState(() => _isUploading = false);
        return;
      }
    }

    List<Map<String, dynamic>> pemegangList = [];
    for (var i = 0; i < _pemegangControllers.length; i++) {
      final pemegang = _pemegangControllers[i];
      String? pemegangImageUrl;

      if (pemegang.imageFile != null) {
        pemegangImageUrl = await _uploadImageFile(pemegang.imageFile!);
        if (pemegangImageUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Gagal mengunggah gambar untuk ${pemegang.nameController.text}.")),
            );
          }
        }
      }
      if (pemegang.nameController.text.isNotEmpty) {
        pemegangList.add({
          'nama': pemegang.nameController.text,
          'imageUrl': pemegangImageUrl,
        });
      }
    }

    Map<String, dynamic> data = {
      'id': docRef.id,
      'namaBarang': _namaBarangController.text,
      'kategoriBarang': _kategoriBarangController.text,
      'imageUrl': itemImageUrl,
      'details': _dynamicFieldControllers
          .map((controllers) => {
                'key': controllers.keyController.text,
                'value': controllers.valueController.text,
              })
          .where((field) => field['key']!.isNotEmpty)
          .toList(),
      'pemegangBarang': pemegangList,
    };

    await docRef.set(data).then((_) {
      if (mounted) context.goNamed('qr_code', extra: docRef.id);
    }).catchError((error) {
      developer.log("Failed to save data: $error", name: "AddItemScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan data: $error")),
        );
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    });
  }

 @override
Widget build(BuildContext context) {
  return Stack(
    children: [
      Scaffold(
        appBar: AppBar(title: const Text('Tambah Data Barang Baru')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildImagePicker(
                isMainImage: true,
                onImagePicked: (file) => setState(() => _itemImageFile = file),
                imageFile: _itemImageFile,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                  _namaBarangController, 'Nama Barang', 'Masukkan nama barang', isRequired: true),
              const SizedBox(height: 16),
              _buildTextField(
                  _kategoriBarangController, 'Kategori Barang', 'Pilih Kategori', isRequired: true),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text("Detail Tambahan",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._buildDynamicFields(),
              const SizedBox(height: 16),
              _buildAddNewFieldButton(),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
               Text("Pemegang Barang",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._buildPemegangFields(),
              const SizedBox(height: 16),
              _buildAddPemegangButton(),

            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: _isUploading ? Colors.grey[700] : null,
            ),
            onPressed: _isUploading ? null : _generateQRCode,
            child: Text(_isUploading ? "Menyimpan Data..." : 'Generate QR Code'),
          ),
        ),
      ),
      if (_isUploading)
        Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
    ],
  );
}

  Widget _buildImagePicker({
    required bool isMainImage,
    required Function(XFile?) onImagePicked,
    XFile? imageFile,
  }) {
    return Center(
      child: GestureDetector(
        onTap: () async {
          final file = await _pickImage();
          onImagePicked(file);
        },
        child: Container(
          height: isMainImage ? 150 : 100,
          width: isMainImage ? 150 : 100,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[400]!, width: 2),
          ),
          child: imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(imageFile.path), fit: BoxFit.cover),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.grey[600], size: isMainImage ? 40 : 30),
                    const SizedBox(height: 8),
                    Text("Pilih Gambar",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: isMainImage ? 14: 12, color: Colors.grey[700])),
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

  List<Widget> _buildPemegangFields() {
    return _pemegangControllers.asMap().entries.map((entry) {
      int index = entry.key;
      var pemegang = entry.value;
      return Padding(
        key: pemegang.key,
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               _buildImagePicker(
                  isMainImage: false,
                  imageFile: pemegang.imageFile,
                  onImagePicked: (file) {
                    setState(() {
                      pemegang.imageFile = file;
                    });
                  },
                ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(pemegang.nameController, 'Nama Pemegang', 'Masukkan nama', isRequired: true)
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _removePemegangField(index),
              )
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAddNewFieldButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(
            width: 1.5,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Tambah Field Baru'),
      onPressed: _addDynamicField,
    );
  }

  Widget _buildAddPemegangButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        foregroundColor: Theme.of(context).colorScheme.secondary,
         side: BorderSide(
            width: 1.5,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Tambah Pemegang Barang'),
      onPressed: _addPemegangField,
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String hint, {bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (isRequired) {
          if (value == null || value.isEmpty) {
            return '$label tidak boleh kosong';
          }
        }
        return null;
      },
    );
  }
}
