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

  // Được gọi khi app resume từ background hoặc quay lại từ màn hình khác
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
          .order('created_at', ascending: false); // Mới nhất lên đầu

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

  void _navigateToAddFace() async {
    // Push và đợi kết quả từ màn hình thêm mặt
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFaceStepsPage()),
    );

    // Nếu thêm thành công, load lại danh sách
    if (result == true && mounted) {
      _fetchFaces();
      // Hiện thông báo thành công
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
                      // Format ngày giờ cho đẹp
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