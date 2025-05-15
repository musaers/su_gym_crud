// lib/screens/admin/admin_memberships_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/service_provider.dart';

class AdminMembershipsScreen extends StatefulWidget {
  const AdminMembershipsScreen({Key? key}) : super(key: key);

  @override
  _AdminMembershipsScreenState createState() => _AdminMembershipsScreenState();
}

class _AdminMembershipsScreenState extends State<AdminMembershipsScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMembershipPlans();
  }

  // Üyelik planlarını yükle
  Future<void> _loadMembershipPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('membership_plans')
          .orderBy('price', descending: false)
          .get();

      List<Map<String, dynamic>> plans = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Firestore'dan gelen verileri düzenleme
        List<Map<String, dynamic>> durations = [];
        if (data['durations'] != null && data['durations'] is List) {
          durations = List<Map<String, dynamic>>.from(
            (data['durations'] as List)
                .map((item) => Map<String, dynamic>.from(item)),
          );
        }

        List<String> features = [];
        if (data['features'] != null && data['features'] is List) {
          features = List<String>.from(data['features']);
        }

        plans.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'durations': durations,
          'features': features,
          'color': _getPlanColor(data['name'] ?? ''),
        });
      }

      setState(() {
        _plans = plans;
        _isLoading = false;
      });

      print('Admin: ${_plans.length} üyelik planı yüklendi');
    } catch (e) {
      print('Üyelik planları yüklenirken hata: $e');
      setState(() {
        _errorMessage = 'Üyelik planları yüklenirken bir hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  // Plan silme işlemi
  Future<void> _deletePlan(String planId, String planName) async {
    try {
      await FirebaseFirestore.instance
          .collection('membership_plans')
          .doc(planId)
          .delete();

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$planName plan deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Planları yenile
      _loadMembershipPlans();
    } catch (e) {
      print('Plan silinirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Plan için renk belirleme
  Color _getPlanColor(String planName) {
    switch (planName.toLowerCase()) {
      case 'premium':
        return Colors.blue;
      case 'platinum':
        return Colors.purple;
      case 'student':
        return Colors.teal;
      case 'family':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Membership Plans',
          style: GoogleFonts.ubuntu(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMembershipPlans,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _plans.isEmpty
                  ? _buildEmptyView()
                  : _buildPlansListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlanDialog,
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add),
        tooltip: 'Add Plan',
      ),
    );
  }

  // Hata durumu gösterimi
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.ubuntu(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMembershipPlans,
              child: Text(
                'Try Again',
                style: GoogleFonts.ubuntu(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Boş liste durumu gösterimi
  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_membership, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              'No membership plans available',
              style: GoogleFonts.ubuntu(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new plan using the + button',
              style: GoogleFonts.ubuntu(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Planlar listesi gösterimi
  Widget _buildPlansListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) => _buildPlanCard(_plans[index]),
    );
  }

  // Plan kartı
  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final planColor = plan['color'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Plan başlığı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: planColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan['name'],
                  style: GoogleFonts.ubuntu(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _showEditPlanDialog(plan),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _showDeleteConfirmation(plan),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Plan detayları
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Açıklama
                Text(
                  plan['description'],
                  style: GoogleFonts.ubuntu(
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),

                // Fiyat seçenekleri
                Text(
                  'Pricing Options:',
                  style: GoogleFonts.ubuntu(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...plan['durations'].map<Widget>((duration) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${duration['months']} ${duration['months'] == 1 ? 'Month' : 'Months'}',
                          style: GoogleFonts.ubuntu(),
                        ),
                        Text(
                          '${duration['price']} TL',
                          style: GoogleFonts.ubuntu(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),

                // Özellikler
                Text(
                  'Features:',
                  style: GoogleFonts.ubuntu(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...plan['features'].map<Widget>((feature) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: planColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: GoogleFonts.ubuntu(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Plan silme onay iletişim kutusu
  void _showDeleteConfirmation(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Plan',
          style: GoogleFonts.ubuntu(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the ${plan['name']} plan? This action cannot be undone.',
          style: GoogleFonts.ubuntu(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.ubuntu(),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deletePlan(plan['id'], plan['name']);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.ubuntu(),
            ),
          ),
        ],
      ),
    );
  }

  // Yeni plan ekleme iletişim kutusu
  void _showAddPlanDialog() {
    // Bu fonksiyonu genişleterek, form ile yeni üyelik planı eklenebilir
    // Şimdilik basit bir mesaj gösterelim
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan creation functionality will be implemented soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Plan düzenleme iletişim kutusu
  void _showEditPlanDialog(Map<String, dynamic> plan) {
    // Bu fonksiyonu genişleterek, form ile üyelik planı düzenlenebilir
    // Şimdilik basit bir mesaj gösterelim
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan editing functionality will be implemented soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
