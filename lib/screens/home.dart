import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'face_list.dart';
import 'authentication.dart';
import 'access_log_page.dart';
import 'setting_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState(); // Sửa thành HomePageState
}

class HomePageState extends State<HomePage> { // Sửa thành HomePageState
  final supabase = Supabase.instance.client;
  int _selectedInterval = 5;
  late RealtimeChannel _accessLogChannel;
  DateTime? _lastNotificationTime;

  @override
  void initState() {
    super.initState();
    loadSettings();
    _setupRealtimeListener();
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
        context, MaterialPageRoute(builder: (context) => const AuthPage()));
  }

  Future<void> _setupRealtimeListener() async {
    _accessLogChannel = supabase.channel('access_log_changes');

    _accessLogChannel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'access_log',
      callback: (payload) {
        if (payload.newRecord != null) {
          Map<String, dynamic> newRecord = payload.newRecord!;
          if (newRecord['stranger'] > 0) {
            _showNotification(newRecord['stranger']);
          }
        }
      },
    )
        .subscribe();
  }

  Future<void> _showNotification(int strangerCount) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('lastNotificationTime') ?? 0);

    // Kiểm tra thời gian hồi
    if (_lastNotificationTime == null ||
        DateTime.now().difference(_lastNotificationTime!) >=
            Duration(seconds: _selectedInterval)) {
      const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails('high_importance_channel',
          'High Importance Notifications',
          priority: Priority.high,
          importance: Importance.max,
          icon: '@mipmap/ic_launcher');

      const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

      await flutterLocalNotificationsPlugin.show(
        0,
        'Có người lạ!',
        'Phát hiện $strangerCount người lạ',
        notificationDetails,
      );

      // Cập nhật thời điểm thông báo cuối cùng
      _lastNotificationTime = DateTime.now();
      await prefs.setInt('lastNotificationTime', _lastNotificationTime!.millisecondsSinceEpoch);
    }
  }

  @override
  void dispose() {
    _accessLogChannel.unsubscribe();
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
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold),
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
                }
            ),
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