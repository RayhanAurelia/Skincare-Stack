import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EditProductPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> initialData;

  const EditProductPage({super.key, required this.productId, required this.initialData});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  
  late String _selectedCategory;
  late String _selectedRoutine;
  DateTime? _selectedDate;
  File? _newImageFile;
  bool _isLoading = false;

  final List<String> _categories = ["Cleanser", "Toner", "Serum", "Moisturizer", "Sunscreen", "Lainnya"];
  final List<String> _routines = ["Pagi", "Malam", "Keduanya"];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _brandController = TextEditingController(text: widget.initialData['brand']);
    _selectedCategory = widget.initialData['category'] ?? "Cleanser";
    _selectedRoutine = widget.initialData['routine'] ?? "Keduanya";
    _selectedDate = (widget.initialData['expiryDate'] as Timestamp).toDate();
  }

  void _showHumanDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Oke', style: TextStyle(color: Color(0xFF3F51B5)))),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) setState(() => _newImageFile = File(pickedFile.path));
  }

  Future<void> _updateProduct() async {
    final String newName = _nameController.text.trim();
    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if (newName.isEmpty) {
      _showHumanDialog('Nama Kosong', 'Nama produknya diisi dulu ya!');
      return;
    }

    if (_selectedDate!.isBefore(today)) {
      _showHumanDialog('Tanggal Kadaluarsa Lewat', 'Pilih tanggal hari ini atau masa depan ya!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // VALIDASI NAMA UNIK (Jika nama diubah)
      if (newName != widget.initialData['name']) {
        final existing = await FirebaseFirestore.instance
            .collection('products')
            .where('userId', isEqualTo: user.uid)
            .where('name', isEqualTo: newName)
            .get();

        if (existing.docs.isNotEmpty) {
          setState(() => _isLoading = false);
          _showHumanDialog('Nama Sudah Ada', 'Nama "$newName" sudah ada di rak kamu.');
          return;
        }
      }

      String finalImageUrl = widget.initialData['imageUrl'];

      // Jika user ganti foto, simpan yang baru secara lokal
      if (_newImageFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}${p.extension(_newImageFile!.path)}';
        final File localImage = await _newImageFile!.copy('${directory.path}/$fileName');
        finalImageUrl = localImage.path;
      }

      await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
        'name': newName,
        'brand': _brandController.text.trim(),
        'category': _selectedCategory,
        'routine': _selectedRoutine,
        'expiryDate': Timestamp.fromDate(_selectedDate!),
        'imageUrl': finalImageUrl,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil diperbarui!')));
      }
    } catch (e) {
      if (mounted) _showHumanDialog('Gagal', 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Produk', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
        backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF3F51B5)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 180, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!)),
                        child: _newImageFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_newImageFile!, fit: BoxFit.cover))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(File(widget.initialData['imageUrl']), fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Ketuk foto untuk menggantinya', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 25),
                    TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nama Produk', border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    TextFormField(controller: _brandController, decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedRoutine,
                      decoration: const InputDecoration(labelText: 'Rutinitas', border: OutlineInputBorder()),
                      items: _routines.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _selectedRoutine = v!),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () async {
                         final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate!,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)), // Biarkan user lihat tgl exp lama
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kadaluarsa: ${DateFormat('dd MMMM yyyy').format(_selectedDate!)}'),
                            const Icon(Icons.calendar_today, color: Color(0xFF3F51B5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _updateProduct, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('Update Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
            ),
    );
  }
}
