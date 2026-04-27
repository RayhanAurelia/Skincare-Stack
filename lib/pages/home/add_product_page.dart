import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:awesome_notifications/awesome_notifications.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  
  String _selectedCategory = "Cleanser";
  String _selectedRoutine = "Keduanya"; // Pagi, Malam, Keduanya
  DateTime? _selectedDate;
  File? _imageFile;
  bool _isLoading = false;

  final List<String> _categories = ["Cleanser", "Toner", "Serum", "Moisturizer", "Sunscreen", "Lainnya"];
  final List<String> _routines = ["Pagi", "Malam", "Keduanya"];

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Izin Notifikasi'),
            content: const Text('Boleh minta izin notifikasi? Biar kami bisa ngingetin kamu pas skincare-nya mau kadaluarsa.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
              TextButton(
                onPressed: () {
                  AwesomeNotifications().requestPermissionToSendNotifications().then((_) => Navigator.pop(context));
                },
                child: const Text('Izinkan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showHumanDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF3F51B5)),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Oke, Saya Paham', style: TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _scheduleNotifications(String productName, DateTime expiryDate, String productId) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    
    int daysUntil = expiryDay.difference(today).inDays;
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (daysUntil <= 3 && daysUntil >= 0) {
      if (isAllowed) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: productId.hashCode + 3,
            channelKey: 'basic_channel',
            title: 'Skincare Alert!',
            body: 'Produk $productName kamu tinggal $daysUntil hari lagi sebelum kadaluarsa.',
          ),
        );
      }
      await _saveNotificationToFirestore(productName, 'Produk ini mendekati kadaluarsa (H-3)', now);
    } else if (daysUntil > 3) {
      DateTime h3Date = expiryDay.subtract(const Duration(days: 3));
      if (isAllowed) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: productId.hashCode + 3,
            channelKey: 'basic_channel',
            title: 'Pengingat Kadaluarsa',
            body: '3 hari lagi produk $productName kamu kadaluarsa ya!',
          ),
          schedule: NotificationCalendar.fromDate(date: h3Date),
        );
      }
      await _saveNotificationToFirestore(productName, 'Akan kadaluarsa dalam 3 hari', h3Date);
    }
  }

  Future<void> _saveNotificationToFirestore(String productName, String message, DateTime scheduledTime) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user.uid,
        'title': 'Skincare Stack Alert',
        'body': '$productName: $message',
        'timestamp': Timestamp.fromDate(scheduledTime),
        'isRead': false,
      });
    }
  }

  Future<void> _saveProduct() async {
    final String productName = _nameController.text.trim();
    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if (productName.isEmpty) {
      _showHumanDialog('Nama Kosong', 'Nama produknya diisi dulu ya!');
      return;
    }

    if (_selectedDate == null) {
      _showHumanDialog('Tanggal Belum Dipilih', 'Pilih kapan kadaluarsanya ya!');
      return;
    }

    if (_selectedDate!.isBefore(today)) {
      _showHumanDialog('Tanggal Kadaluarsa Lewat', 'Waduh, produk ini sepertinya sudah kadaluarsa.');
      return;
    }

    if (_imageFile == null) {
      _showHumanDialog('Foto Wajib', 'Potret dulu produknya ya!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final existing = await FirebaseFirestore.instance
          .collection('products')
          .where('userId', isEqualTo: user.uid)
          .where('name', isEqualTo: productName)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        _showHumanDialog('Nama Sudah Ada', 'Nama "$productName" sudah ada di rak kamu.');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}${p.extension(_imageFile!.path)}';
      final File localImage = await _imageFile!.copy('${directory.path}/$fileName');

      DocumentReference docRef = await FirebaseFirestore.instance.collection('products').add({
        'name': productName,
        'brand': _brandController.text.trim(),
        'category': _selectedCategory,
        'routine': _selectedRoutine, // AM, PM, Both logic
        'expiryDate': Timestamp.fromDate(_selectedDate!),
        'imageUrl': localImage.path,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _scheduleNotifications(productName, _selectedDate!, docRef.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil disimpan!')));
      }
    } catch (e) {
      if (mounted) _showHumanDialog('Kesalahan Sistem', 'Maaf, ada gangguan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Produk Baru', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
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
                        child: _imageFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_imageFile!, fit: BoxFit.cover))
                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Color(0xFF3F51B5)), SizedBox(height: 10), Text('Ambil Foto Produk', style: TextStyle(color: Color(0xFF3F51B5)))]),
                      ),
                    ),
                    const SizedBox(height: 25),
                    TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'Nama Produk', prefixIcon: const Icon(Icons.shopping_bag_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 15),
                    TextFormField(controller: _brandController, decoration: InputDecoration(labelText: 'Brand / Merek', prefixIcon: const Icon(Icons.branding_watermark_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(labelText: 'Kategori', prefixIcon: const Icon(Icons.category_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 15),
                    // Pilihan Rutinitas
                    DropdownButtonFormField<String>(
                      value: _selectedRoutine,
                      decoration: InputDecoration(labelText: 'Dipakai Kapan?', prefixIcon: const Icon(Icons.access_time), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: _routines.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _selectedRoutine = v!),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [const Icon(Icons.calendar_month_outlined, color: Color(0xFF3F51B5)), const SizedBox(width: 10), Text(_selectedDate == null ? 'Pilih Tanggal Kedaluwarsa' : 'Exp: ${DateFormat('dd MMMM yyyy').format(_selectedDate!)}')]),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF3F51B5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveProduct, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('Simpan ke Rak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
            ),
    );
  }
}
