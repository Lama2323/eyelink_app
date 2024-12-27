import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:screen_brightness/screen_brightness.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  double? _currentBrightness;
  double _exposureOffset = 0.0;

  // Kích thước elip 
  double ellipseWidth = 120;
  double ellipseHeight = 160;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.setExposureMode(ExposureMode.auto);
      _controller.getMaxExposureOffset().then((maxOffset) {
        if (maxOffset >= 1) {
          _controller.setExposureOffset(1.0);
          setState(() {
            _exposureOffset = 1.0;
          });
        } else {
          _controller.setExposureOffset(maxOffset);
          setState(() {
            _exposureOffset = maxOffset;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<File?> _captureAndCropImage() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      await _initializeControllerFuture;

      // Lưu độ sáng hiện tại
      _currentBrightness = await ScreenBrightness().current;

      // Đặt độ sáng màn hình lên mức cao nhất
      await ScreenBrightness().setScreenBrightness(1.0);

      // Delay 100ms để màn hình nháy sáng
      await Future.delayed(const Duration(milliseconds: 100));

      // Chụp ảnh
      final XFile imageFile = await _controller.takePicture();

      // Lấy đường dẫn tạm thời
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, 'original_image.jpg');

      // Copy ảnh gốc đến đường dẫn mới (không crop, không resize)
      File originalFile = File(imageFile.path);
      await originalFile.copy(targetPath);

      return File(targetPath);
    } catch (e) {
      print("Lỗi chụp ảnh: $e");
      return null;
    } finally {
      setState(() {
        _isProcessing = false;
      });

      // Trả độ sáng về mức ban đầu
      if (_currentBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_currentBrightness!);
      }
    }
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final size = MediaQuery.of(context).size;
            final double cameraAspectRatio = _controller.value.aspectRatio;

            return Stack(
              children: [
                // Camera Preview
                Center(
                  child: SizedBox(
                    width: size.width,
                    height: size.width / cameraAspectRatio,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: SizedBox(
                            width: size.width,
                            height: size.width * cameraAspectRatio,
                            child: CameraPreview(_controller), // Camera
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Khung elip
                Center(
                  child: SizedBox(
                    width: ellipseWidth,
                    height: ellipseHeight,
                    child: CustomPaint(
                      painter: EllipsePainter(),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80.0), 
                    child: Text(
                      'Đặt khuôn mặt vào khung elip',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Nút chụp
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_exposureOffset != 0.0)
                          Text(
                            'Exposure: ${_exposureOffset.toStringAsFixed(1)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                            File? processedImage =
                            await _captureAndCropImage();
                            if (processedImage != null) {
                              if (!mounted) return;
                              Navigator.pop(context, processedImage);
                            } else {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Chụp ảnh thất bại')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                          ),
                          child: _isProcessing
                              ? const CircularProgressIndicator(
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.black),
                          )
                              : const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Flash effect (sáng trắng khi chụp)
                if (_isProcessing)
                  Container(
                    color: Colors.white,
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

// Vẽ elip
class EllipsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawOval(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}