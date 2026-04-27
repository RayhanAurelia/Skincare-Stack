import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/welcome_page.dart';
import 'profile_settings_page.dart';
import 'shelf_page.dart';
import 'notifications_page.dart';
import 'skin_journal_page.dart';
import 'add_product_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  String _username = "...";
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _username = doc.data()?['fullName'] ?? "User";
            _profileImageUrl = doc.data()?['profileImageUrl'];
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardPage(username: _username, profileImageUrl: _profileImageUrl),
      const ShelfPage(),
      const SkinJournalPage(),
      const ProfileSettingsPage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3F51B5),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Shelf'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Journal'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String username;
  final String? profileImageUrl;
  const DashboardPage({super.key, required this.username, this.profileImageUrl});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _user = FirebaseAuth.instance.currentUser;
  Timer? _timer;
  String _countdownText = "";
  String _routineType = "Pagi";

  @override
  void initState() {
    super.initState();
    _updateRoutineType();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRoutineType() {
    final hour = DateTime.now().hour;
    setState(() {
      _routineType = (hour >= 5 && hour < 16) ? "Pagi" : "Malam";
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _calculateCountdown();
    });
    _calculateCountdown();
  }

  void _calculateCountdown() {
    final now = DateTime.now();
    int amHour = 8; 
    int pmHour = 20;
    DateTime target;
    String label;

    if (now.hour < amHour) {
      target = DateTime(now.year, now.month, now.day, amHour);
      label = "Morning Routine";
    } else if (now.hour < pmHour) {
      target = DateTime(now.year, now.month, now.day, pmHour);
      label = "Night Routine";
    } else {
      target = DateTime(now.year, now.month, now.day + 1, amHour);
      label = "Morning Routine";
    }

    final diff = target.difference(now);
    if (mounted) {
      setState(() {
        if (diff.inMinutes <= 0) {
          _countdownText = "It's time for your Skincare!";
        } else {
          _countdownText = "Next: $label in ${diff.inHours}h ${diff.inMinutes % 60}m";
        }
      });
    }
  }

  String _getTodayDateKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_box, color: Color(0xFF3F51B5)),
              title: const Text('Tambah Produk Baru'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEEE, d MMMM y').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skincare Stack', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage())),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSettingsPage()));
              } else if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomePage()), (route) => false);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: widget.profileImageUrl != null 
                    ? FileImage(File(widget.profileImageUrl!)) as ImageProvider
                    : null,
                child: widget.profileImageUrl == null ? const Icon(Icons.person, color: Color(0xFF3F51B5)) : null,
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, size: 20), SizedBox(width: 8), Text('Pengaturan')])),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 20, color: Colors.red), SizedBox(width: 8), Text('Logout', style: TextStyle(color: Colors.red))])),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        backgroundColor: const Color(0xFF3F51B5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Welcome back, ', style: TextStyle(fontSize: 20, color: Colors.grey)),
                Expanded(
                  child: Text(
                    widget.username,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(formattedDate, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6A82FB), Color(0xFF3F51B5)]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 30),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _countdownText,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            _buildSectionHeader('Routine Checklist ($_routineType)'),
            const SizedBox(height: 10),
            _buildRoutineChecklist(),

            const SizedBox(height: 30),
            _buildSectionHeader('Skin Progress'),
            const SizedBox(height: 15),
            _buildMiniGallery(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildRoutineChecklist() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('userId', isEqualTo: _user?.uid)
          .where('routine', whereIn: [_routineType, "Keduanya"])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        final products = snapshot.data?.docs ?? [];
        if (products.isEmpty) return const Text('Belum ada produk untuk rutin ini.');

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('daily_logs')
              .where('userId', isEqualTo: _user?.uid)
              .where('date', isEqualTo: _getTodayDateKey())
              .snapshots(),
          builder: (context, logSnapshot) {
            final doneIds = logSnapshot.hasData 
                ? logSnapshot.data!.docs.map((d) => d['productId'] as String).toSet() 
                : <String>{};
            
            double progress = products.isEmpty ? 0 : doneIds.length / products.length;

            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF3F51B5),
                  ),
                ),
                const SizedBox(height: 15),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final pId = p.id;
                    final bool isDone = doneIds.contains(pId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: CheckboxListTile(
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p['brand']),
                        value: isDone,
                        activeColor: const Color(0xFF3F51B5),
                        onChanged: (val) async {
                          if (val == true) {
                            await FirebaseFirestore.instance.collection('daily_logs').add({
                              'userId': _user?.uid,
                              'productId': pId,
                              'date': _getTodayDateKey(),
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          } else {
                            final logs = await FirebaseFirestore.instance
                                .collection('daily_logs')
                                .where('userId', isEqualTo: _user?.uid)
                                .where('productId', isEqualTo: pId)
                                .where('date', isEqualTo: _getTodayDateKey())
                                .get();
                            for (var doc in logs.docs) {
                              await doc.reference.delete();
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMiniGallery() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('journal_entries')
          .where('userId', isEqualTo: _user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100);
        
        // Ambil data dan urutkan manual (Client-side) untuk menghindari error Index
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Text('Belum ada foto journal!');

        final sortedDocs = List.from(docs);
        sortedDocs.sort((a, b) {
          var aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          var bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          return (bTime ?? Timestamp.now()).compareTo(aTime ?? Timestamp.now());
        });

        final limitDocs = sortedDocs.take(3).toList();

        return SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: limitDocs.length,
            itemBuilder: (context, index) {
              final data = limitDocs[index].data() as Map<String, dynamic>;
              final File imageFile = File(data['imageUrl']);

              return Container(
                width: 110,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  border: Border.all(color: Colors.white, width: 2),
                  image: DecorationImage(
                    image: FileImage(imageFile),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        DateFormat('dd MMM').format((data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now()),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
