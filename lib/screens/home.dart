import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'face_list.dart';
import 'login_page.dart';
import 'access_log_page.dart';
import 'setting_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  int _selectedInterval = 5;
  DateTime? _lastNotificationTime;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedInterval = prefs.getInt('checkInterval') ?? 5;
      _lastNotificationTime =
          DateTime.fromMillisecondsSinceEpoch(prefs.getInt('lastNotificationTime') ?? 0);
    });
  }

  void _logout(BuildContext context) async {
    await supabase.auth.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách người quen'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const ListTile(
                title: Text(
                  'Menu',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                )),
            ListTile(
              title: const Text('Danh sách người quen'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Lịch sử nhận diện'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AccessLogPage())),
            ),
            ListTile(
                title: const Text('Cài đặt'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingPage()),
                  );
                }),
            ListTile(
              title: const Text('Đăng xuất'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: const FaceListPage(),
    );
  }
}