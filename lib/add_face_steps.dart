import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;

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

  Future<File?> _resizeImage(File imageFile) async {
    try {
      // Đọc file ảnh
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;

      // Tính toán kích thước mới để đạt ~2 megapixel (1920x1080)
      final resized = img.copyResize(
        image,
        width: 1920,
        height: 1080,
        interpolation: img.Interpolation.linear
      );

      // Tạo file tạm để lưu ảnh đã resize
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Encode và lưu ảnh với chất lượng 90%
      final compressedBytes = img.encodeJpg(resized, quality: 90);
      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      print('Lỗi resize ảnh: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.front,
      );

      if (!mounted || pickedFile == null) return;

      // Crop ảnh
      final croppedFile = await _cropImage(pickedFile.path);
      if (!mounted || croppedFile == null) return;

      // Resize ảnh đã crop
      final resizedFile = await _resizeImage(croppedFile);
      if (!mounted || resizedFile == null) return;

      // Cleanup files
      final originalFile = File(pickedFile.path);
      if (originalFile.existsSync()) {
        await originalFile.delete();
      }
      if (croppedFile.path != resizedFile.path && croppedFile.existsSync()) {
        await croppedFile.delete();
      }

      setState(() {
        _images.add(resizedFile);
      });

      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        await _handleFinalStep();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _handleFinalStep() async {
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _uploadData();

      if (!mounted) return;
      Navigator.of(context).pop(); // Đóng dialog loading
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Đóng dialog loading
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
      await _pickImage();
    }
  }

  Future<File?> _cropImage(String imagePath) async {
  if (!mounted) return null;
  
  try {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 640, ratioY: 480),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Điều chỉnh ảnh',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: true,
          hideBottomControls: false,
          dimmedLayerColor: Colors.black.withOpacity(0.8),
          activeControlsWidgetColor: Colors.blue,
        ),
        IOSUiSettings(
          title: 'Điều chỉnh ảnh',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          rotateButtonsHidden: true,
          resetButtonHidden: true,
        ),
      ],
      cropStyle: CropStyle.rectangle,
      compressQuality: 90,
      compressFormat: ImageCompressFormat.jpg,
    );

    if (!mounted || croppedFile == null) return null;
    
    final file = File(croppedFile.path);
    if (!file.existsSync()) return null;
    
    return file;
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi crop ảnh: $e')),
      );
    }
    return null;
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
    // Cleanup tất cả ảnh tạm khi widget bị dispose
    for (final image in _images) {
      if (image.existsSync()) {
        image.delete().catchError((_) {});
      }
    }
    _nameController.dispose();
    super.dispose();
  }

}