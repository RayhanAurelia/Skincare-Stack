import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class SkinJournalPage extends StatefulWidget {
  const SkinJournalPage({super.key});

  @override
  State<SkinJournalPage> createState() => _SkinJournalPageState();
}

class _SkinJournalPageState extends State<SkinJournalPage> {
  final _user = FirebaseAuth.instance.currentUser;
  bool _isCompareMode = false;
  final List<Map<String, dynamic>> _selectedForCompare = [];

  void _toggleCompareMode() {
    setState(() {
      _isCompareMode = !_isCompareMode;
      _selectedForCompare.clear();
    });
  }

  void _onEntryTap(Map<String, dynamic> data) {
    if (_isCompareMode) {
      setState(() {
        if (_selectedForCompare.any((e) => e['id'] == data['id'])) {
          _selectedForCompare.removeWhere((e) => e['id'] == data['id']);
        } else if (_selectedForCompare.length < 2) {
          _selectedForCompare.add(data);
        }
      });
      if (_selectedForCompare.length == 2) {
        _showComparisonDialog();
      }
    } else {
      _showEntryDetail(data);
    }
  }

  void _showComparisonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Skin Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Row(
                children: [
                  Expanded(child: _buildCompareItem(_selectedForCompare[0])),
                  Container(width: 2, height: 200, color: Colors.grey[300]),
                  Expanded(child: _buildCompareItem(_selectedForCompare[1])),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompareItem(Map<String, dynamic> data) {
    return Column(
      children: [
        Image.file(File(data['imageUrl']), height: 200, fit: BoxFit.cover),
        const SizedBox(height: 8),
        Text(DateFormat('dd MMM yy').format((data['timestamp'] as Timestamp).toDate()), style: const TextStyle(fontWeight: FontWeight.bold)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(data['note'] ?? '', style: const TextStyle(fontSize: 12), maxLines: 2, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  void _showEntryDetail(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(File(data['imageUrl']), fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            Text(DateFormat('EEEE, dd MMMM yyyy').format((data['timestamp'] as Timestamp).toDate()), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(data['note'] ?? 'No log entry.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('journal_entries').doc(data['id']).delete();
              Navigator.pop(context);
            },
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _addNewEntry() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);

    if (pickedFile != null) {
      final noteController = TextEditingController();
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Log Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(File(pickedFile.path), height: 150),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(hintText: 'How is your skin today?'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      );

      if (confirmed == true && _user != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String fileName = 'journal_${_user!.uid}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
        final File localImage = await File(pickedFile.path).copy('${directory.path}/$fileName');

        await FirebaseFirestore.instance.collection('journal_entries').add({
          'userId': _user!.uid,
          'imageUrl': localImage.path,
          'note': noteController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Journal', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
        actions: [
          TextButton.icon(
            onPressed: _toggleCompareMode,
            icon: Icon(_isCompareMode ? Icons.close : Icons.compare, color: Color(0xFF3F51B5)),
            label: Text(_isCompareMode ? 'Cancel' : 'Compare', style: const TextStyle(color: Color(0xFF3F51B5))),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isCompareMode)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue[50],
              child: Text('Select 2 photos to compare (${_selectedForCompare.length}/2)', style: const TextStyle(color: Colors.blue)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('journal_entries')
                  .where('userId', isEqualTo: _user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No journal entries yet. Start tracking!'));

                final docs = snapshot.data!.docs;
                // Sort client side for real-time without index issues
                docs.sort((a, b) {
                  var aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  var bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  return (bTime ?? Timestamp.now()).compareTo(aTime ?? Timestamp.now());
                });

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    data['id'] = docs[index].id;
                    final bool isSelected = _selectedForCompare.any((e) => e['id'] == data['id']);

                    return GestureDetector(
                      onTap: () => _onEntryTap(data),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(File(data['imageUrl']), fit: BoxFit.cover),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue, width: 3),
                              ),
                              child: const Center(child: Icon(Icons.check_circle, color: Colors.white)),
                            ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                DateFormat('dd MMM').format((data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now()),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
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
        onPressed: _addNewEntry,
        backgroundColor: const Color(0xFF3F51B5),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}
