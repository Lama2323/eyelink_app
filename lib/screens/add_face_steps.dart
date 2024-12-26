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
      Navigator.of(context).pop(); 
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); 
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
        title: const Text('Thêm người quen', style: TextStyle(fontWeight: FontWeight.bold)), // Bold title
      ),
      body: SingleChildScrollView(
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
                    // Giới hạn chiều cao của TextField
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