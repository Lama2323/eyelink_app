import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_face_steps.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'face_detail.dart';

class FaceListPage extends StatefulWidget {
  const FaceListPage({super.key});

  @override
  _FaceListPageState createState() => _FaceListPageState();
}

class _FaceListPageState extends State<FaceListPage>
    with WidgetsBindingObserver {
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
          faces =
              (response as List).map((item) => item as Map<String, dynamic>).toList();
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
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final folderPath = face['name'];
      try {
        final List<FileObject> files = await supabase.storage
            .from('face')
            .list(path: folderPath);
        for (var file in files) {
          await supabase.storage
              .from('face')
              .remove(['$folderPath/${file.name}']);
        }
        await supabase.storage
            .from('face')
            .remove([folderPath]);
      } catch (e) {
        debugPrint('Storage cleanup error: $e');
      }

      await supabase
          .from('face')
          .delete()
          .match({'id': face['id']});

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchFaces();
      }
    } catch (error) {
      if (mounted) {
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
                      final timeAgo = timeago.format(createdAt, locale: 'vi');

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FaceDetailPage(face: face),
                                    ),
                                  ).then((_) {
                                    _fetchFaces();
                                  });
                                },
                                leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey, 
                                    ),
                                    child: const Icon(
                                        Icons.person,
                                        color: Colors.white
                                    )
                                ),
                                title: Text(
                                  face['name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Đã thêm: $timeAgo',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteFace(face),
                                ),
                              ),
                            )),
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