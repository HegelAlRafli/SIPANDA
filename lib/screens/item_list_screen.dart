import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  String _searchQuery = '';
  String _sortOrder = 'asc'; // 'asc' or 'desc'
  String _sortBy = 'namaBarang'; // Default sort by name

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Daftar Barang', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
            onSelected: (value) {
              setState(() {
                if (value == 'asc' || value == 'desc') {
                  _sortOrder = value;
                } else {
                  _sortBy = value;
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'namaBarang',
                child: Text('Urutkan berdasarkan Nama'),
              ),
              const PopupMenuItem<String>(
                value: 'kategoriBarang',
                child: Text('Urutkan berdasarkan Kategori'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'asc',
                child: Text('Ascending'),
              ),
              const PopupMenuItem<String>(
                value: 'desc',
                child: Text('Descending'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Card(
              elevation: 1.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari barang...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('items')
                  .orderBy(_sortBy, descending: _sortOrder == 'desc')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Terjadi kesalahan'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final namaBarang = (data['namaBarang'] ?? '').toString().toLowerCase();
                  final searchQuery = _searchQuery.toLowerCase();
                  return namaBarang.contains(searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Barang tidak ditemukan atau belum ada.'),
                      ));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final document = filteredDocs[index];
                    final data = document.data()! as Map<String, dynamic>;
                    final itemId = document.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      elevation: 1.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        leading: Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Icon(
                            Icons.qr_code,
                            color: Theme.of(context).primaryColor,
                            size: 24.0,
                          ),
                        ),
                        title: Text(
                          data['namaBarang'] ?? 'Tanpa Nama',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(data['kategoriBarang'] ?? 'Tanpa Kategori'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          context.goNamed('item_details', pathParameters: {'itemId': itemId});
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/add_item');
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white,),
      ),
    );
  }
}
