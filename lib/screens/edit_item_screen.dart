
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as developer;
import 'package:myapp/models/dynamic_field_model.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;
  const EditItemScreen({super.key, required this.itemId});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaBarangController;
  late TextEditingController _kategoriBarangController;
  final List<DynamicFieldControllers> _dynamicFieldControllers = [];

  final String _imgbbApiKey = "062dd36a9ba0bd8ec04a44ecd3fe896b";

  XFile? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _namaBarangController = TextEditingController();
    _kategoriBarangController = TextEditingController();
    _fetchItemData();
  }

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

  Future<void> _fetchItemData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        _namaBarangController.text = data['namaBarang'] ?? '';
        _kategoriBarangController.text = data['kategoriBarang'] ?? '';
        _existingImageUrl = data['imageUrl'];

        if (data['details'] != null) {
          for (var detail in data['details']) {
            final key = detail['key'] ?? '';
            final value = detail['value'] ?? '';
            _dynamicFieldControllers.add(
              DynamicFieldControllers(
                keyController: TextEditingController(text: key),
                valueController: TextEditingController(text: value),
              ),
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error fetching item data: $e', name: 'EditItemScreen');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data barang: $e')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      developer.log('Image picking failed: $e', name: 'EditItemScreen');
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
    if (_imageFile == null) return _existingImageUrl;

    var request = http.MultipartRequest(
        'POST', Uri.parse('https://api.imgbb.com/1/upload'));

    request.fields['key'] = _imgbbApiKey;

    request.files.add(
      await http.MultipartFile.fromPath('image', _imageFile!.path),
    );

    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final json = jsonDecode(respStr);
        final imageUrl = json['data']['url'];
        developer.log("New image uploaded to imgbb: $imageUrl",
            name: "EditItemScreen");
        return imageUrl;
      } else {
        final errorBody = await response.stream.bytesToString();
        developer.log(
            "Image upload failed with status ${response.statusCode}: $errorBody",
            name: "EditItemScreen");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Gagal mengunggah gambar baru: ${response.reasonPhrase}")),
          );
        }
        return null;
      }
    } catch (e) {
      developer.log("Image upload failed: $e", name: "EditItemScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengunggah gambar baru: $e")),
        );
      }
      return null;
    }
  }

  void _updateItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      String? newImageUrl = await _uploadImage(widget.itemId);
      if (_imageFile != null && newImageUrl == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      Map<String, dynamic> data = {
        'id': widget.itemId,
        'namaBarang': _namaBarangController.text,
        'kategoriBarang': _kategoriBarangController.text,
        'imageUrl': newImageUrl,
        'details': _dynamicFieldControllers
            .map((controllers) => {
                  'key': controllers.keyController.text,
                  'value': controllers.valueController.text,
                })
            .where((field) => field['key']!.isNotEmpty)
            .toList(),
      };

      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .update(data)
          .then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data barang berhasil diperbarui!')),
          );
          context.pop();
        }
      }).catchError((error) {
        if (mounted) {
          developer.log('Failed to update data: $error', name: 'EditItemScreen');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui data: $error')),
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
  }

@override
Widget build(BuildContext context) {
  return Stack(
    children: [
      Scaffold(
        appBar: AppBar(title: const Text('Edit Data Barang')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildTextField(_namaBarangController, 'Nama Barang',
                        'Masukkan nama barang'),
                    const SizedBox(height: 16),
                    _buildTextField(_kategoriBarangController, 'Kategori Barang',
                        'Pilih Kategori'),
                    const SizedBox(height: 24),
                    Text('Detail Tambahan',
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
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: _isUploading ? Colors.grey[700] : null,
            ),
            onPressed: _isUploading ? null : _updateItem,
            child: _isUploading 
                ? const Text("Sedang Memperbarui...") 
                : const Text('Update Data Barang'),
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

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _isUploading ? null : _pickImage,
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
                  child: Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                )
              : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(_existingImageUrl!, fit: BoxFit.cover, 
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 48, color: Colors.grey), 
                        loadingBuilder: (context, child, loadingProgress) {
                          if(loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        }
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt,
                            color: Colors.grey[600], size: 40),
                        const SizedBox(height: 8),
                        Text('Pilih Gambar',
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    )),
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
          borderSide:
              BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
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
