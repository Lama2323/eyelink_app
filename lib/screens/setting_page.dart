import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('checkInterval', _selectedInterval);
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
                  title: const Text('Khoảng thời gian kiểm tra'),
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
                      DropdownMenuItem(value: 2, child: Text('2 giây')),
                      DropdownMenuItem(value: 4, child: Text('4 giây')),
                      DropdownMenuItem(value: 5, child: Text('5 giây')),
                      DropdownMenuItem(value: 10, child: Text('10 giây')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}