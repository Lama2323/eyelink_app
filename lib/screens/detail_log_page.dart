import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailLogPage extends StatelessWidget {
  final Map<String, dynamic> logData;

  const DetailLogPage({Key? key, required this.logData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Chuyển đổi thời gian sang giờ địa phương trước khi hiển thị
    final time = DateTime.parse(logData['time']).toLocal();
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
    final strangerCount = logData['stranger'];
    // Sửa List<String> thành List<dynamic>
    final faceNames = List<dynamic>.from(logData['face_name'] ?? []);
    final acquaintanceCount = faceNames.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết log'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch to full width
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thời gian: $formattedTime',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.warning, color: Colors.red),
                      title: Text('Người lạ: $strangerCount'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.green),
                      title: Text('Người quen: $acquaintanceCount'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (faceNames.isNotEmpty)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tên người quen:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...faceNames.map((name) => ListTile(
                            leading: const Icon(Icons.face, color: Colors.blue), // Add an icon for face names
                            title: Text(name),
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}