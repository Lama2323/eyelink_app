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
  String _selectedFilter = 'Ngày';
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  Stream<List<Map<String, dynamic>>> _getAccessLogStream() {
    return supabase
        .from('access_log')
        .stream(primaryKey: ['id'])
        .map((maps) => maps as List<Map<String, dynamic>>)
        .map((data) {
          data = data.where((log) {
            return log['stranger'] > 0 || (log['face_name'] != null && (log['face_name'] as List).isNotEmpty);
          }).toList();

          if (_startDate == null || _endDate == null) return data;

          return data.where((log) { 
            final logTime = DateTime.parse(log['time']).toUtc();

            // Kiểm tra khoảng thời gian
            DateTime startDateTime, endDateTime;
            switch (_selectedFilter) {
              case 'Giờ':
                if (_startTime == null || _endTime == null) return false;
                startDateTime = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime!.hour, _startTime!.minute);
                endDateTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute);
                break;
              case 'Ngày':
                startDateTime = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
                endDateTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
                break;
              case 'Tháng':
                startDateTime = DateTime(_startDate!.year, _startDate!.month);
                endDateTime = DateTime(_endDate!.year, _endDate!.month + 1).subtract(const Duration(seconds: 1));
                break;
              case 'Năm':
                startDateTime = DateTime(_startDate!.year);
                endDateTime = DateTime(_endDate!.year + 1).subtract(const Duration(seconds: 1));
                break;
              default:
                return true;
            }
            return logTime.isAfter(startDateTime) && logTime.isBefore(endDateTime);
          }).toList();
        });
  }

  Future<void> _selectStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
        if (_selectedFilter == 'Giờ') {
          _selectStartTime();
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
        if (_selectedFilter == 'Giờ') {
          _selectEndTime();
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (pickedTime != null) {
      setState(() {
        _startTime = pickedTime;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (pickedTime != null) {
      setState(() {
        _endTime = pickedTime;
      });
    }
  }

  String _getFormattedStartDate() {
    if (_startDate == null) return 'Chọn';
    switch (_selectedFilter) {
      case 'Giờ':
        return _startTime != null ? '${DateFormat('HH:mm').format(DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime!.hour, _startTime!.minute))} ${DateFormat('dd/MM/yyyy').format(_startDate!)}' : 'Chọn';
      case 'Ngày':
        return DateFormat('dd/MM/yyyy').format(_startDate!);
      case 'Tháng':
        return DateFormat('MM/yyyy').format(_startDate!);
      case 'Năm':
        return DateFormat('yyyy').format(_startDate!);
      default:
        return 'Chọn';
    }
  }

  String _getFormattedEndDate() {
    if (_endDate == null) return 'Chọn';
    switch (_selectedFilter) {
      case 'Giờ':
        return _endTime != null ? '${DateFormat('HH:mm').format(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute))} ${DateFormat('dd/MM/yyyy').format(_endDate!)}' : 'Chọn';
      case 'Ngày':
        return DateFormat('dd/MM/yyyy').format(_endDate!);
      case 'Tháng':
        return DateFormat('MM/yyyy').format(_endDate!);
      case 'Năm':
        return DateFormat('yyyy').format(_endDate!);
      default:
        return 'Chọn';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử nhận diện'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  value: _selectedFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedFilter = newValue!;
                      _startDate = null;
                      _endDate = null;
                      _startTime = null;
                      _endTime = null;
                    });
                  },
                  items: <String>['Giờ', 'Ngày', 'Tháng', 'Năm']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _selectStartDate,
                      child: Text(_getFormattedStartDate()),
                    ),
                    ElevatedButton(
                      onPressed: _selectEndDate,
                      child: Text(_getFormattedEndDate()),
                    ),
                  ],
                )

              ],
            ),
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
                    final time = DateTime.parse(log['time']).toLocal();
                    final formattedTime =
                        DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
                    final strangerCount = log['stranger'];
                    final faceNames = List<dynamic>.from(log['face_name'] ?? []);
                    final acquaintanceCount = faceNames.isNotEmpty? faceNames.length : 0;
                    final strangerColor =
                        strangerCount > 0 ? Colors.red : Colors.grey;
                    final acquaintanceColor =
                        acquaintanceCount > 0 ? Colors.green : Colors.grey;

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
                                  const Icon(Icons.access_time,
                                      size: 20, color: Colors.grey),
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
                                        Icon(Icons.warning,
                                            size: 18, color: strangerColor),
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
                                        Icon(Icons.person,
                                            size: 18, color: acquaintanceColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Người quen: $acquaintanceCount',
                                          style:
                                              TextStyle(color: acquaintanceColor),
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