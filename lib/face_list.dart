import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_face_steps.dart';

class FaceListPage extends StatefulWidget {
  const FaceListPage({super.key});

  @override
  _FaceListPageState createState() => _FaceListPageState();
}

class _FaceListPageState extends State<FaceListPage> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> faces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchFaces();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchFaces();
    }
  }

  Future<void> _fetchFaces() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await supabase
          .from('face')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          faces = (response as List).map((item) => item as Map<String, dynamic>).toList();
          isLoading = false;
        });
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi không xác định: $error')),
        );
      }
    }
  }

  Future<void> _deleteFace(Map<String, dynamic> face) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc muốn xóa ${face['name']}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Delete images from storage
      final folderPath = face['name'];
      try {
        final List<FileObject> files = await supabase.storage
            .from('face')
            .list(path: folderPath);

        // Delete each file in the folder
        for (var file in files) {
          await supabase.storage
              .from('face')
              .remove(['$folderPath/${file.name}']);
        }

        // Remove the empty folder
        await supabase.storage
            .from('face')
            .remove([folderPath]);
      } catch (e) {
        // If folder/files don't exist, continue with database deletion
        debugPrint('Storage cleanup error: $e');
      }

      // Delete record from database
      await supabase
          .from('face')
          .delete()
          .match({'id': face['id']});

      if (mounted) {
        // Remove loading indicator
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the list
        _fetchFaces();
      }
    } catch (error) {
      if (mounted) {
        // Remove loading indicator
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToAddFace() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFaceStepsPage()),
    );

    if (result == true && mounted) {
      _fetchFaces();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thêm người quen thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchFaces,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : faces.isEmpty
                ? const Center(
                    child: Text('Chưa có người quen nào', 
                      style: TextStyle(fontSize: 16)),
                  )
                : ListView.builder(
                    itemCount: faces.length,
                    itemBuilder: (context, index) {
                      final face = faces[index];
                      final createdAt = DateTime.parse(face['created_at']);
                      final formattedDate = 
                          '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute}';
                      
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          face['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        subtitle: Text(
                          'Đã thêm: $formattedDate',
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteFace(face),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddFace,
        child: const Icon(Icons.add),
      ),
    );
  }
}