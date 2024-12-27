import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
  bool _isLoading = false;

  final List<Map<String, dynamic>> _steps = [
    {
      'instruction': 'Nhập tên người cần thêm',
      'icon': Icons.person_add_alt_1_rounded,
    },
    {
      'instruction': 'Chụp hình chính diện',
      'icon': Icons.face_retouching_natural_rounded,
    },
    {
      'instruction': 'Chụp hình mặt quay trái',
      'icon': Icons.arrow_circle_left_outlined,
    },
    {
      'instruction': 'Chụp hình mặt quay phải',
      'icon': Icons.arrow_circle_right_outlined,
    },
    {
      'instruction': 'Chụp hình mặt ngước lên',
      'icon': Icons.arrow_circle_up_outlined,
    },
    {
      'instruction': 'Chụp hình mặt cúi xuống',
      'icon': Icons.arrow_circle_down_outlined,
    },
  ];

  Future<void> _handleFinalStep() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      await _uploadData();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  void _nextStep() async {
    if (!mounted) return;

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
      // Mở CameraScreen
      final cameras = await availableCameras();
      final firstCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final File? croppedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(camera: firstCamera),
        ),
      );

      if (croppedImage != null) {
        // Tạo một File object mới từ đường dẫn của ảnh trả về
        final String newImagePath = await duplicateImage(croppedImage);
        setState(() {
          _images.add(File(newImagePath)); // Thêm File mới vào danh sách
        });

        if (_currentStep < _steps.length - 1) {
          setState(() {
            _currentStep++;
          });
        } else {
          await _handleFinalStep();
        }
      }
    }
  }
    // Hàm để duplicate ảnh và trả về đường dẫn mới
  Future<String> duplicateImage(File originalImage) async {
    final tempDir = await getTemporaryDirectory();
    final originalFileName = path.basename(originalImage.path);
    final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
    final newImagePath = path.join(tempDir.path, uniqueFileName);

    // Copy ảnh
    await originalImage.copy(newImagePath);
    return newImagePath;
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
      } on PostgrestException catch (e) {
        throw Exception('Lỗi lưu dữ liệu: ${e.message}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải lên: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm người quen', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step['icon'],
                  size: 80,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                step['instruction'],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              if (_currentStep == 0)
                Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: SizedBox(
                      height: 70,
                      child: TextField(
                        controller: _nameController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: 'Tên',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                    )
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final image in _images) {
      if (image.existsSync()) {
        image.delete().catchError((_) {});
      }
    }
    _nameController.dispose();
    super.dispose();
  }
}