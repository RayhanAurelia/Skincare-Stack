import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _oldPasswordVerifyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  String? _profileImagePath;
  bool _isLoading = false;
  bool _isOldPasswordVerified = false;
  bool _obscureOldPass = true;
  bool _obscureNewPass = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      final doc = await _firestore.collection('users').doc(_user.uid).get();
      if (doc.exists) {
        setState(() {
          _nameController.text = doc.data()?['fullName'] ?? "";
          _emailController.text = _user.email ?? "";
          _profileImagePath = doc.data()?['profileImageUrl'];
        });
      }
    }
  }

  void _showPopup(String title, String message, {bool isError = true}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isError ? Colors.red : Colors.green)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF3F51B5))),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOldPassword() async {
    if (_oldPasswordVerifyController.text.isEmpty) {
      _showPopup('Input Kosong', 'Masukkan password lama kamu dulu ya sebagai verifikasi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: _oldPasswordVerifyController.text,
      );
      await _user.reauthenticateWithCredential(credential);
      
      if (mounted) {
        setState(() {
          _isOldPasswordVerified = true;
          _isLoading = false;
        });
        Navigator.pop(context); // Close modal
        _showPopup('Verifikasi Berhasil', 'Password lama kamu benar! Sekarang kamu bisa memasukkan password baru.', isError: false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Menangani kode error 'wrong-password' atau 'invalid-credential' dengan bahasa manusia
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _showPopup('Password Salah', 'Waduh, password lama yang kamu masukkan salah nih. Coba diingat-ingat lagi ya.');
        } else {
          _showPopup('Oops!', 'Sepertinya ada masalah: ${e.message}');
        }
      }
    }
  }

  void _showVerifyPasswordModal() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Verifikasi Password', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Masukkan password lama kamu untuk melanjutkan penggantian password baru.'),
              const SizedBox(height: 20),
              TextField(
                controller: _oldPasswordVerifyController,
                obscureText: _obscureOldPass,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3F51B5)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOldPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setModalState(() => _obscureOldPass = !_obscureOldPass),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOldPassword,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white),
              child: const Text('Verifikasi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSaveImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (pickedFile != null && _user != null) {
      setState(() => _isLoading = true);
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String fileName = 'profile_${_user.uid}${p.extension(pickedFile.path)}';
        final File localImage = await File(pickedFile.path).copy('${directory.path}/$fileName');
        
        await _firestore.collection('users').doc(_user.uid).update({'profileImageUrl': localImage.path});
        
        if (mounted) {
          setState(() => _profileImagePath = localImage.path);
          _showPopup('Berhasil', 'Foto profil kamu sudah diperbarui di HP ini!', isError: false);
        }
      } catch (e) {
        if (mounted) _showPopup('Gagal', 'Maaf, gagal menyimpan foto ke HP.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_user == null) return;
    if (_nameController.text.trim().isEmpty) {
      _showPopup('Nama Kosong', 'Nama lengkap tidak boleh kosong ya.');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('users').doc(_user.uid).update({'fullName': _nameController.text.trim()});

      if (_isOldPasswordVerified && _newPasswordController.text.isNotEmpty) {
        if (_newPasswordController.text.length < 6) {
          _showPopup('Password Pendek', 'Password baru minimal 6 karakter ya!');
          setState(() => _isLoading = false);
          return;
        }
        await _user.updatePassword(_newPasswordController.text);
        _newPasswordController.clear();
        _oldPasswordVerifyController.clear();
        _isOldPasswordVerified = false;
      }

      if (mounted) {
        _showPopup('Berhasil', 'Perubahan profil kamu sudah disimpan.', isError: false);
      }
    } catch (e) {
      if (mounted) _showPopup('Error', 'Gangguan sistem: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3F51B5)),
          onPressed: () => Navigator.maybePop(context),
        ) : null,
        title: const Text('Skincare Stack', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF3F51B5)),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5))) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAndSaveImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60, backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImagePath != null ? FileImage(File(_profileImagePath!)) : null,
                    child: _profileImagePath == null ? const Icon(Icons.person, size: 60, color: Color(0xFF3F51B5)) : null,
                  ),
                  Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF3F51B5), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 20))),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.person, color: Color(0xFF3F51B5)))),
            const SizedBox(height: 20),
            TextField(controller: _emailController, enabled: false, decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.email, color: Color(0xFF3F51B5)), filled: true, fillColor: Colors.grey[100])),
            const Divider(height: 60, thickness: 1),
            
            if (!_isOldPasswordVerified) 
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showVerifyPasswordModal,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Ganti Password'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), foregroundColor: const Color(0xFF3F51B5), side: const BorderSide(color: Color(0xFF3F51B5))),
                ),
              )
            else 
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Masukkan Password Baru', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPass,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      prefixIcon: const Icon(Icons.lock, color: Colors.green),
                      suffixIcon: IconButton(icon: Icon(_obscureNewPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                child: const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
