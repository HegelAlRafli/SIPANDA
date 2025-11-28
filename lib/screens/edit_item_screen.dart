
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as developer;
import 'package:myapp/widgets/dynamic_field.dart';

// Helper class to manage state for each "Pemegang Barang"
class _PemegangBarangControllers {
  final TextEditingController nameController;
  XFile? imageFile;
  String? existingImageUrl;
  final GlobalKey key = GlobalKey();

  _PemegangBarangControllers({
    String name = '',
    this.imageFile,
    this.existingImageUrl,
  }) : nameController = TextEditingController(text: name);
}

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
  final List<_PemegangBarangControllers> _pemegangControllers = [];

  final String _imgbbApiKey = "062dd36a9ba0bd8ec04a44ecd3fe896b";

  XFile? _itemImageFile;
  String? _existingItemImageUrl;
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
      controllerPair.dispose();
    }
    for (var pemegang in _pemegangControllers) {
      pemegang.nameController.dispose();
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
        _existingItemImageUrl = data['imageUrl'];

        if (data['details'] != null && data['details'] is List) {
          for (var detail in data['details']) {
            // CORRECTED INITIALIZATION LOGIC
            final controllers = DynamicFieldControllers();
            controllers.keyController.text = detail['key'] ?? '';
            controllers.valueController.text = detail['value'] ?? '';
            _dynamicFieldControllers.add(controllers);
          }
        }

        if (data['pemegangBarang'] != null && data['pemegangBarang'] is List) {
          for (var pemegangData in data['pemegangBarang']) {
            _pemegangControllers.add(_PemegangBarangControllers(
              name: pemegangData['nama'] ?? '',
              existingImageUrl: pemegangData['imageUrl'],
            ));
          }
        }

      }
    } catch (e) {
      developer.log('Error fetching item data: $e', name: 'EditItemScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data barang: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<XFile?> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      return await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      developer.log('Image picking failed: $e', name: 'EditItemScreen');
      return null;
    }
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
        return jsonDecode(respStr)['data']['url'];
      } else {
        developer.log('Upload failed: ${response.statusCode}', name: 'Upload');
        return null;
      }
    } catch (e) {
      developer.log('Upload exception: $e', name: 'Upload');
      return null;
    }
  }

  void _updateItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    String? finalItemImageUrl = _existingItemImageUrl;
    if (_itemImageFile != null) {
      finalItemImageUrl = await _uploadImageFile(_itemImageFile!);
      if (finalItemImageUrl == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengunggah gambar utama.")));
        setState(() => _isUploading = false);
        return;
      }
    }

    List<Map<String, dynamic>> pemegangList = [];
    for (var pemegang in _pemegangControllers) {
      String? finalPemegangImageUrl = pemegang.existingImageUrl;
      if (pemegang.imageFile != null) {
        finalPemegangImageUrl = await _uploadImageFile(pemegang.imageFile!);
      }
      if (pemegang.nameController.text.isNotEmpty) {
        pemegangList.add({
          'nama': pemegang.nameController.text,
          'imageUrl': finalPemegangImageUrl,
        });
      }
    }

    Map<String, dynamic> dataToUpdate = {
      'namaBarang': _namaBarangController.text,
      'kategoriBarang': _kategoriBarangController.text,
      'imageUrl': finalItemImageUrl,
      'details': _dynamicFieldControllers
          .map((c) => {'key': c.keyController.text, 'value': c.valueController.text})
          .where((f) => f['key']!.isNotEmpty)
          .toList(),
      'pemegangBarang': pemegangList,
    };

    await FirebaseFirestore.instance.collection('items').doc(widget.itemId).update(dataToUpdate).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil diperbarui')));
        context.pop();
      }
    }).catchError((error) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memperbarui data: $error")));
    }).whenComplete(() {
      if (mounted) setState(() => _isUploading = false);
    });
  }

  void _addDynamicField() => setState(() => _dynamicFieldControllers.add(DynamicFieldControllers()));
  
  void _removeDynamicField(int index) => setState(() {
    _dynamicFieldControllers[index].dispose();
    _dynamicFieldControllers.removeAt(index);
  });

  void _addPemegangField() => setState(() => _pemegangControllers.add(_PemegangBarangControllers()));
  
  void _removePemegangField(int index) => setState(() {
    _pemegangControllers[index].nameController.dispose();
    _pemegangControllers.removeAt(index);
  });

@override
Widget build(BuildContext context) {
  return Stack(children: [
    Scaffold(
      appBar: AppBar(title: const Text('Edit Data Barang')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildItemImagePicker(),
                  const SizedBox(height: 24),
                  _buildTextField(_namaBarangController, 'Nama Barang', 'Masukkan nama barang', isRequired: true),
                  const SizedBox(height: 16),
                  _buildTextField(_kategoriBarangController, 'Kategori Barang', 'Pilih Kategori', isRequired: true),
                  const Divider(height: 32),
                  Text("Detail Tambahan", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ..._buildDynamicFields(),
                  const SizedBox(height: 16),
                  _buildAddNewFieldButton(),
                  const Divider(height: 32),
                  Text("Pemegang Barang", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
          onPressed: _isUploading ? null : _updateItem,
          child: Text(_isUploading ? "Menyimpan..." : 'Simpan Perubahan'),
        ),
      ),
    ),
    if (_isUploading) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
  ]);
}

  Widget _buildItemImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _isUploading ? null : () async {
          final file = await _pickImage();
          if (file != null) setState(() => _itemImageFile = file);
        },
        child: Container(
          height: 150, width: 150,
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[400]!)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _itemImageFile != null
              ? Image.file(File(_itemImageFile!.path), fit: BoxFit.cover)
              : (_existingItemImageUrl != null
                  ? Image.network(_existingItemImageUrl!, fit: BoxFit.cover, 
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      loadingBuilder: (c, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: Colors.grey[600], size: 40), const SizedBox(height: 8), Text('Ubah Gambar', style: TextStyle(color: Colors.grey[700]))])
          )),
      ),), 
    );
  }

  List<Widget> _buildDynamicFields() {
    return _dynamicFieldControllers.asMap().entries.map((entry) {
      int index = entry.key;
      var c = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(children: [
          Expanded(child: _buildTextField(c.keyController, 'Contoh: Warna', 'Key')),
          const SizedBox(width: 16),
          Expanded(child: _buildTextField(c.valueController, 'Contoh: Merah', 'Value')),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeDynamicField(index))
        ]),
      );
    }).toList();
  }

  List<Widget> _buildPemegangFields() {
    return _pemegangControllers.asMap().entries.map((entry) {
      int index = entry.key;
      var p = entry.value;
      return Padding(
        key: p.key,
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            GestureDetector(
              onTap: _isUploading ? null : () async {
                final file = await _pickImage();
                if (file != null) setState(() => p.imageFile = file);
              },
              child: Container(
                height: 80, width: 80,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[400]!)),
                child: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: p.imageFile != null
                    ? Image.file(File(p.imageFile!.path), fit: BoxFit.cover)
                    : (p.existingImageUrl != null
                        ? Image.network(p.existingImageUrl!, fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey), 
                            loadingBuilder: (c, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 24, color: Colors.grey[600]), const SizedBox(height: 4), Text('Ubah Foto', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey[700]))]))
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField(p.nameController, 'Nama Pemegang', 'Masukkan nama', isRequired: true)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _removePemegangField(index))
          ]),
        ),
      );
    }).toList();
  }

  Widget _buildAddNewFieldButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.add), label: const Text('Tambah Field Baru'),
      onPressed: _addDynamicField,
    );
  }

  Widget _buildAddPemegangButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), foregroundColor: Theme.of(context).colorScheme.secondary, side: BorderSide(color: Theme.of(context).colorScheme.secondary.withOpacity(0.7)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.person_add_alt_1), label: const Text('Tambah Pemegang Barang'),
      onPressed: _addPemegangField,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0))),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$label tidak boleh kosong';
        }
        return null;
      },
    );
  }
}
