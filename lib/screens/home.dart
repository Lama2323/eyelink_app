import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../face_list.dart';
import 'authentication.dart';

class HomePage extends StatelessWidget {
  final supabase = Supabase.instance.client;

  HomePage({super.key});

  void _logout(BuildContext context) async {
    await supabase.auth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthPage()));
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
                  fontSize: 30,
                  fontWeight: FontWeight.bold
                ),
              )
            ),
            ListTile(
              title: const Text('Danh sách người quen'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Lịch sử ra vào'),
              //onTap: () => ,
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
