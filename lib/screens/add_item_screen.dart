import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:myapp/widgets/dynamic_field.dart';
import 'dart:developer' as developer;

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
  void initState() {
    super.initState();
    // Add some default fields as shown in the image
    _dynamicFieldControllers.add(DynamicFieldControllers()
      ..keyController.text = 'Tahun dibuat'
      ..valueController.text = '2023');
    _dynamicFieldControllers.add(DynamicFieldControllers()
      ..keyController.text = 'Pemilik pertama'
      ..valueController.text = 'John Doe');
  }

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
      // Dispose controllers before removing
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
        final imageUrl = json['data']['url'];
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
        if (pemegangImageUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Gagal mengunggah gambar untuk ${pemegang.nameController.text}.")),
          );
          // We can decide to continue or stop. For now, let's continue.
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
          backgroundColor: const Color(0xFFF7F8FC),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Tambah Data Barang Baru',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                _buildMainImagePicker(),
                const SizedBox(height: 20),
                _buildLabel('Nama Barang'),
                _buildTextField(_namaBarangController, 'Masukkan nama barang',
                    isRequired: true),
                const SizedBox(height: 20),
                _buildLabel('Kategori Barang'),
                _buildTextField(_kategoriBarangController, 'Pilih Kategori',
                    isRequired: true),
                const SizedBox(height: 30),
                _buildLabel('Detail Tambahan'),
                ..._buildDynamicFields(),
                const SizedBox(height: 10),
                _buildDashedButton(
                  onPressed: _addDynamicField,
                  text: 'Tambah Field Baru',
                  icon: Icons.add_circle,
                ),
                const SizedBox(height: 30),
                _buildLabel('Pemegang barang'),
                ..._buildPemegangFields(),
                const SizedBox(height: 10),
                _buildDashedButton(
                  onPressed: _addPemegangField,
                  text: 'Tambah Pemegang barang',
                  icon: Icons.group_add,
                ),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              onPressed: _isUploading ? null : _generateQRCode,
              child: Text(
                _isUploading ? "Menyimpan Data..." : 'Generate QR Code',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildMainImagePicker() {
    return GestureDetector(
      onTap: () async {
        final file = await _pickImage();
        if (file != null) {
          setState(() {
            _itemImageFile = file;
          });
        }
      },
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: _itemImageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: Image.file(
                  File(_itemImageFile!.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Text('Gagal memuat gambar')),
                ),
              )
            : const Center(
                child: Text(
                  'Pilih gambar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black54,
                  ),
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
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            Expanded(
                child: _buildTextField(
                    controllers.keyController, 'Contoh: Warna')),
            const SizedBox(width: 12),
            Expanded(
                child: _buildTextField(
                    controllers.valueController, 'Contoh: Merah')),
            const SizedBox(width: 8),
            _buildDeleteButton(() => _removeDynamicField(index)),
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
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPemegangImagePicker(
              imageFile: pemegang.imageFile,
              onImagePicked: (file) {
                if (file != null) {
                  setState(() {
                    pemegang.imageFile = file;
                  });
                }
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Nama Pemegang barang'),
                  _buildTextField(pemegang.nameController, '',
                      isRequired: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildDeleteButton(() => _removePemegangField(index)),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPemegangImagePicker({
    required Function(XFile?) onImagePicked,
    XFile? imageFile,
  }) {
    return GestureDetector(
      onTap: () async {
        final file = await _pickImage();
        onImagePicked(file);
      },
      child: Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Image.file(File(imageFile.path), fit: BoxFit.cover),
              )
            : const Center(
                child: Text('Pilih gambar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildDeleteButton(VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete, color: Colors.red, size: 22),
      ),
    );
  }

  Widget _buildDashedButton(
      {required VoidCallback onPressed,
      required String text,
      required IconData icon}) {
    return DottedBorder(
      options: CustomPathDottedBorderOptions(
        customPath: (size) => Path()
          ..moveTo(0, size.height)
          ..relativeLineTo(size.width, 0),
        color: Theme.of(context).primaryColor,
        strokeWidth: 1.5,
        dashPattern: const [8, 4],

        padding: EdgeInsets.zero, // Important to avoid extra padding
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 22),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: Colors.white,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (isRequired) {
          if (value == null || value.isEmpty) {
            return '$hint tidak boleh kosong';
          }
        }
        return null;
      },
    );
  }
}
