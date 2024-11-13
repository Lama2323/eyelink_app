import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class AddFaceStepsPage extends StatefulWidget {
  const AddFaceStepsPage({super.key});

  @override
  _AddFaceStepsPageState createState() => _AddFaceStepsPageState();
}

class _AddFaceStepsPageState extends State<AddFaceStepsPage> {
  final supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  int _currentStep = 0;
  final List<File> _images = [];

  final List<Map<String, dynamic>> _steps = [
    {
      'instruction': 'Nhập tên người cần thêm',
      'icon': Icons.person,
    },
    {
      'instruction': 'Chụp hình chính diện',
      'icon': Icons.face,
    },
    {
      'instruction': 'Chụp hình mặt quay trái',
      'icon': Icons.arrow_back,
    },
    {
      'instruction': 'Chụp hình mặt quay phải',
      'icon': Icons.arrow_forward,
    },
    {
      'instruction': 'Chụp hình mặt ngước lên',
      'icon': Icons.arrow_upward,
    },
    {
      'instruction': 'Chụp hình mặt cúi xuống',
      'icon': Icons.arrow_downward,
    },
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa chụp hình')),
        );
      }
    }
  }

  Future<void> _uploadData() async {
    final name = _nameController.text.trim();
    final folderPath = name;

    try {
      // Upload images to Supabase Storage
      for (int i = 0; i < _images.length; i++) {
        final file = _images[i];
        final fileName = 'image_$i.jpg';
        final filePath = '$folderPath/$fileName';
        
        // Read file as bytes
        final fileBytes = await file.readAsBytes();
        
        try {
          await supabase.storage
            .from('face')
            .uploadBinary(
              filePath,
              fileBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
              ),
            );
        } on StorageException catch (e) {
          throw Exception('Lỗi upload ảnh ${i + 1}: ${e.message}');
        }
      }

      // Save data to Supabase Table
      try {
        await supabase
            .from('face')
            .insert({
              'name': name,
            });

        if (mounted) {
          // Navigate back to the previous screen with result
          Navigator.pop(context, true);
        }
      } on PostgrestException catch (e) {
        throw Exception('Lỗi lưu dữ liệu: ${e.message}');
      }
    } catch (error) {
      if (mounted) {
        // Display the error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải lên: $error')),
        );
      }
    }
  }

  void _nextStep() async {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên')),
        );
        return;
      }
      setState(() {
        _currentStep++;
      });
    } else {
      await _pickImage();
      if (_images.length < _currentStep) {
        // User didn't pick an image
        return;
      }
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        if (mounted) {
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Center(child: CircularProgressIndicator())
            ),
          );
        }

        // Perform upload
        await _uploadData();

        if (mounted) {
          // Hide loading indicator
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm người quen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(
                step['icon'],
                size: 120,
              ),
              const SizedBox(height: 20),
              Text(
                step['instruction'],
                style: const TextStyle(fontSize: 18),
              ),
              if (_currentStep == 0)
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên'),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _nextStep,
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}