import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class FaceDetailPage extends StatefulWidget {
  final Map<String, dynamic> face;

  const FaceDetailPage({Key? key, required this.face}) : super(key: key);

  @override
  _FaceDetailPageState createState() => _FaceDetailPageState();
}

class _FaceDetailPageState extends State<FaceDetailPage> {
  final supabase = Supabase.instance.client;
  late String _imageUrl;
  late String _name;
  late DateTime _createdAt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _name = widget.face['name'];
    _createdAt = DateTime.parse(widget.face['created_at']);
    _imageUrl = '';
    _fetchImageUrl();
  }

  Future<void> _fetchImageUrl() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final folderPath = widget.face['name'];
      final fileName = 'image_0.jpg';

      final String imageUrl = await supabase.storage
          .from('face')
          .createSignedUrl('$folderPath/$fileName', 60 * 60 * 24 * 365 * 10); 

      setState(() {
        _imageUrl = imageUrl;
      });
    } catch (e) {
      debugPrint('Error fetching image URL: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final nameController = TextEditingController(text: _name);
        return AlertDialog(
          title: const Text('Chỉnh sửa tên'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Nhập tên mới"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Lưu'),
              onPressed: () => Navigator.of(context).pop(nameController.text),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != _name) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await supabase
            .from('face')
            .update({'name': newName})
            .match({'id': widget.face['id']});

        final oldFolderPath = _name;
        final newFolderPath = newName;
        final List<FileObject> files =
            await supabase.storage.from('face').list(path: oldFolderPath);
        for (var file in files) {
          final oldFilePath = '$oldFolderPath/${file.name}';
          final newFilePath = '$newFolderPath/${file.name}';
          await supabase.storage.from('face').move(oldFilePath, newFilePath);
        }

        setState(() {
          _name = newName;
        });

        await _fetchImageUrl();

        if (mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật tên thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi cập nhật tên: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _imageUrl.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Image.network(
                  _imageUrl,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.person, size: 150);
                  },
                ),
              )
                  : const Icon(Icons.person, size: 150),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đã thêm: ${timeago.format(_createdAt, locale: 'vi')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _editName,
        backgroundColor: Colors.blue,
        tooltip: 'Chỉnh sửa tên',
        child: const Icon(Icons.edit),
      ),
    );
  }
}