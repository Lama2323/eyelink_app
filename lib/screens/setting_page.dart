import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'change_password_page.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  int _selectedInterval = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedInterval = prefs.getInt('checkInterval') ?? 5;
    });
      final service = FlutterBackgroundService();
    if (_selectedInterval != 0) {
        if (await service.isRunning()) {
          service.invoke('reloadSettings');
        } else {
          service.startService();
        }
    }
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('checkInterval', _selectedInterval);

    final service = FlutterBackgroundService();
    if (_selectedInterval == 0) {
      // Dừng service nếu chọn "Tắt"
      service.invoke('stopService');
    } else {
      // Khởi động lại service nếu chọn các khoảng thời gian khác
       if (await service.isRunning()) {
          service.invoke('reloadSettings');
        } else {
          service.startService();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Chu kỳ thông báo'),
                  trailing: DropdownButton<int>(
                    value: _selectedInterval,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedInterval = newValue;
                        });
                        _saveSettings();
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Tắt')),
                      DropdownMenuItem(value: 5, child: Text('5 giây')),
                      DropdownMenuItem(value: 10, child: Text('10 giây')),
                      DropdownMenuItem(value: 30, child: Text('30 giây')),
                      DropdownMenuItem(value: 60, child: Text('60 giây')),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Đổi mật khẩu'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChangePasswordPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}