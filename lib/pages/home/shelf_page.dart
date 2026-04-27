import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_product_page.dart';
import 'edit_product_page.dart';

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final _user = FirebaseAuth.instance.currentUser;
  String _searchQuery = "";
  String _selectedCategory = "Semua";

  final List<String> _categories = ["Semua", "Cleanser", "Toner", "Serum", "Moisturizer", "Sunscreen", "Lainnya"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rak Skincare Kamu', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari produk kamu...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF3F51B5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3F51B5) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('userId', isEqualTo: _user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Terjadi kesalahan.'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var products = snapshot.data!.docs;
                var filteredProducts = products.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  var name = (data['name'] ?? "").toString().toLowerCase();
                  var category = data['category'] ?? "Semua";
                  bool matchesSearch = name.contains(_searchQuery);
                  bool matchesCategory = _selectedCategory == "Semua" || category == _selectedCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const Center(child: Text('Rak kamu masih kosong.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    var doc = filteredProducts[index];
                    return ProductCard(data: doc.data() as Map<String, dynamic>, productId: doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
        },
        backgroundColor: const Color(0xFF3F51B5),
        child: const Icon(Icons.add_photo_alternate, color: Colors.white),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String productId;
  const ProductCard({super.key, required this.data, required this.productId});

  @override
  Widget build(BuildContext context) {
    DateTime? expiryDate;
    if (data['expiryDate'] != null) {
      expiryDate = (data['expiryDate'] as Timestamp).toDate();
    }
    
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? expDay = expiryDate != null ? DateTime(expiryDate.year, expiryDate.month, expiryDate.day) : null;

    bool isExpired = expDay != null && (expDay.isBefore(today) || expDay.isAtSameMomentAs(today));
    bool isExpiringSoon = expDay != null && !isExpired && expDay.difference(today).inDays <= 3;

    final String routine = data['routine'] ?? 'Keduanya';

    ImageProvider? imageProvider;
    String? imageUrl = data['imageUrl'];
    if (imageUrl != null) {
      if (imageUrl.startsWith('http')) {
        imageProvider = NetworkImage(imageUrl);
      } else {
        imageProvider = FileImage(File(imageUrl));
      }
    }

    return GestureDetector(
      onDoubleTap: () => _showDetail(context, expiryDate),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
                      color: Colors.grey[300],
                    ),
                    child: imageProvider == null ? const Center(child: Icon(Icons.image_not_supported)) : null,
                  ),
                  // Delete Button
                  Positioned(
                    top: 5, right: 5,
                    child: GestureDetector(
                      onTap: () => _deleteProduct(context),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                        child: const Icon(Icons.delete, color: Colors.red, size: 18),
                      ),
                    ),
                  ),
                  // Edit Button
                  Positioned(
                    top: 5, left: 5,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditProductPage(productId: productId, initialData: data)));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Color(0xFF3F51B5), size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(data['brand'] ?? 'Brand', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  const SizedBox(height: 5),
                  
                  Row(
                    children: [
                      Icon(
                        routine == "Pagi" ? Icons.wb_sunny_outlined : routine == "Malam" ? Icons.nightlight_outlined : Icons.wb_twilight,
                        size: 12,
                        color: const Color(0xFF3F51B5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        routine,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF3F51B5), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  if (expDay != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.green[100]),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isExpired ? 'SUDAH HABIS' : (isExpiringSoon ? 'Hampir Habis' : 'Aman'),
                        style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.bold,
                          color: isExpired || isExpiringSoon ? Colors.white : Colors.green[800],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, DateTime? expiryDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(data['name'] ?? 'Detail Produk', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Brand: ${data['brand'] ?? '-'}'),
            Text('Kategori: ${data['category'] ?? '-'}'),
            Text('Rutinitas: ${data['routine'] ?? 'Keduanya'}'),
            const SizedBox(height: 10),
            Text('Kadaluarsa: ${expiryDate != null ? DateFormat('dd MMMM yyyy').format(expiryDate) : '-'}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  void _deleteProduct(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Yakin mau hapus "${data['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(productId).delete();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}
