import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'detail_log_page.dart';

class AccessLogPage extends StatefulWidget {
  const AccessLogPage({super.key});

  @override
  State<AccessLogPage> createState() => _AccessLogPageState();
}

class _AccessLogPageState extends State<AccessLogPage> {
  final supabase = Supabase.instance.client;
  String _selectedFilter = 'Giờ gần đây';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Stream<List<Map<String, dynamic>>> _getAccessLogStream() {
    return supabase
        .from('access_log')
        .stream(primaryKey: ['id'])
        .map((maps) => maps as List<Map<String, dynamic>>)
        .map((data) {
          // Mặc định lấy dữ liệu 1 giờ trước đến hiện tại
          if (_selectedFilter == 'Giờ gần đây') {
            final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
            return data.where((log) {
              final logTime = DateTime.parse(log['time']);
              return logTime.isAfter(oneHourAgo);
            }).toList();
          }

          if (_selectedDate == null) return data;

          return data.where((log) {
            final logTime = DateTime.parse(log['time']);
            
            switch (_selectedFilter) {
              case 'Giờ xác định':
                if (_selectedTime == null) return false;
                return logTime.year == _selectedDate!.year &&
                    logTime.month == _selectedDate!.month &&
                    logTime.day == _selectedDate!.day &&
                    logTime.hour == _selectedTime!.hour;
              case 'Phút xác định':
                if (_selectedTime == null) return false;
                return logTime.year == _selectedDate!.year &&
                    logTime.month == _selectedDate!.month &&
                    logTime.day == _selectedDate!.day &&
                    logTime.hour == _selectedTime!.hour &&
                    logTime.minute == _selectedTime!.minute;
              case 'Ngày':
                return logTime.year == _selectedDate!.year &&
                    logTime.month == _selectedDate!.month &&
                    logTime.day == _selectedDate!.day;
              case 'Tháng':
                return logTime.year == _selectedDate!.year &&
                    logTime.month == _selectedDate!.month;
              case 'Năm':
                return logTime.year == _selectedDate!.year;
              default:
                return true;
            }
          }).toList();
        });
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      if (_selectedFilter == 'Giờ xác định' || _selectedFilter == 'Phút xác định') {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: _selectedTime ?? TimeOfDay.now(),
        );
        if (pickedTime != null) {
          setState(() {
            _selectedDate = pickedDate;
            _selectedTime = pickedTime;
          });
        }
      } else {
        setState(() {
          _selectedDate = pickedDate;
        });
      }
    }
  }

  String _getFormattedDateTime() {
    if (_selectedDate == null) return 'Chọn thời gian';

    switch (_selectedFilter) {
      case 'Giờ xác định':
      case 'Phút xác định':
        if (_selectedTime == null) return 'Chọn thời gian';
        return '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} ${_selectedTime!.format(context)}';
      case 'Ngày':
        return DateFormat('yyyy-MM-dd').format(_selectedDate!);
      case 'Tháng':
        return DateFormat('yyyy-MM').format(_selectedDate!);
      case 'Năm':
        return DateFormat('yyyy').format(_selectedDate!);
      default:
        return 'Chọn thời gian';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử nhận diện'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              DropdownButton<String>(
                value: _selectedFilter,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFilter = newValue!;
                    if (newValue == 'Giờ gần đây') {
                      _selectedDate = null;
                      _selectedTime = null;
                    }
                  });
                },
                items: <String>[
                  'Giờ gần đây',
                  'Phút xác định',
                  'Giờ xác định',
                  'Ngày',
                  'Tháng',
                  'Năm'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              if (_selectedFilter != 'Giờ gần đây')
                ElevatedButton(
                  onPressed: _selectDateTime,
                  child: Text(_getFormattedDateTime()),
                ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAccessLogStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Không có dữ liệu.'));
                }

                final accessLogs = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: accessLogs.length,
                  itemBuilder: (context, index) {
                    final log = accessLogs[index];
                    final time = DateTime.parse(log['time']);
                    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
                    final strangerCount = log['stranger'];
                    final faceNames = List<String>.from(log['face_name'] ?? []);
                    final acquaintanceCount = faceNames.length;
                    final strangerColor = strangerCount > 0 ? Colors.red : Colors.grey;
                    final acquaintanceColor = acquaintanceCount > 0 ? Colors.green : Colors.grey;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailLogPage(logData: log),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: strangerColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning, size: 18, color: strangerColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Người lạ: $strangerCount',
                                          style: TextStyle(color: strangerColor),
                                        ),
                                      ],
                                    ),
                                  ),                             
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: acquaintanceColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, size: 18, color: acquaintanceColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Người quen: $acquaintanceCount',
                                          style: TextStyle(color: acquaintanceColor),
                                        ),
                                      ],
                                    ),                                 
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}