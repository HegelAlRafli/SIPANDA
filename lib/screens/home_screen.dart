import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/widgets/home_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Barangku'),
        leading: const SizedBox(width: 48), // Placeholder for balance
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: Navigate to history screen
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            HomeCard(
              icon: Icons.qr_code,
              title: 'Generate QR Barang',
              subtitle: 'Buat kode QR untuk barang Anda.',
              buttonText: 'Buat QR',
              onPressed: () => context.go('/add_item'),
            ),
            const SizedBox(height: 16),
            HomeCard(
              icon: Icons.qr_code_scanner,
              title: 'Scan QR Barang',
              subtitle: 'Pindai kode QR untuk melihat detail barang.',
              buttonText: 'Pindai',
              onPressed: () => context.go('/scan_qr'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.view_list), label: 'Daftar Barang'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            context.go('/item_list');
          }
        },
      ),
    );
  }
}
