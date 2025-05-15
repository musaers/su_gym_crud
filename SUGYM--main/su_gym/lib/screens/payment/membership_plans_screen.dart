// lib/screens/payment/membership_plans_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/service_provider.dart';

class MembershipPlansScreen extends StatefulWidget {
  const MembershipPlansScreen({super.key});

  @override
  _MembershipPlansScreenState createState() => _MembershipPlansScreenState();
}

class _MembershipPlansScreenState extends State<MembershipPlansScreen> {
  // Seçilen planın indeksi
  int _selectedPlanIndex = -1;

  // Firestore'dan gelecek planlar
  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMembershipPlans();
  }

  // Üyelik planlarını Firestore'dan yükle
  Future<void> _loadMembershipPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('membership_plans')
          .orderBy('price', descending: false) // Fiyata göre sırala
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

      print('${_plans.length} üyelik planı yüklendi');
    } catch (e) {
      print('Üyelik planları yüklenirken hata: $e');
      setState(() {
        _errorMessage = 'Üyelik planları yüklenirken bir hata oluştu: $e';
        _isLoading = false;
      });
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
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _plans.isEmpty
                  ? _buildEmptyView()
                  : _buildPlansListView(),
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
              'Please check back later',
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your plan',
              style: GoogleFonts.ubuntu(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the membership plan that works best for you.',
              style: GoogleFonts.ubuntu(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Üyelik planları listesi
            ...List.generate(
              _plans.length,
              (index) => _buildPlanCard(context, _plans[index], index),
            ),
          ],
        ),
      ),
    );
  }

  // Plan kartı widget'ı
  Widget _buildPlanCard(
      BuildContext context, Map<String, dynamic> plan, int index) {
    final isSelected = _selectedPlanIndex == index;
    final Color planColor = plan['color'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? planColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? planColor.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan başlığı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: planColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    plan['name'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ubuntu(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan['description'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ubuntu(
                      color: Colors.white,
                      fontSize: 14,
                    ),
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
                  // Süre ve fiyat seçenekleri
                  ..._buildDurationOptions(plan['durations']),
                  const SizedBox(height: 16),

                  // Özellikler başlığı
                  Text(
                    'Features:',
                    style: GoogleFonts.ubuntu(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Özellikler listesi
                  ...plan['features'].map<Widget>((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: planColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
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

                  const SizedBox(height: 20),

                  // Satın al düğmesi
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: planColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showPaymentDialog(context, plan),
                      child: Text(
                        'Buy',
                        style: GoogleFonts.ubuntu(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Süre ve fiyat seçenekleri
  List<Widget> _buildDurationOptions(List<dynamic> durations) {
    return durations.map<Widget>((duration) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Duration: ${duration['months']} ${duration['months'] == 1 ? 'Month' : 'Months'}',
              style: GoogleFonts.ubuntu(fontSize: 16),
            ),
            Text(
              'Price: ${duration['price']} TL',
              style: GoogleFonts.ubuntu(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Ödeme onay iletişim kutusu
  void _showPaymentDialog(BuildContext context, Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Purchase ${plan['name']} Plan?',
          style: GoogleFonts.ubuntu(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You will be directed to payment. Continue?',
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
              backgroundColor: plan['color'],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Ödeme işlemi ve üyeliği güncelleme
              _processMembershipPurchase(plan);
              Navigator.pop(context);
            },
            child: Text(
              'Proceed',
              style: GoogleFonts.ubuntu(),
            ),
          ),
        ],
      ),
    );
  }

  // Üyelik satın alma işlemi
  Future<void> _processMembershipPurchase(Map<String, dynamic> plan) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to purchase a membership');
      }

      // Örnek olarak ilk süre seçeneğini kullanıyoruz, gerçek bir uygulamada
      // kullanıcının seçtiği süre seçeneğini kullanmanız gerekir
      final firstDuration = plan['durations'][0];
      final months = firstDuration['months'] as int;

      // Başlangıç ve bitiş tarihlerini hesapla
      final now = DateTime.now();
      final startDate = now;
      final endDate = now.add(Duration(days: 30 * months));

      // Kullanıcının üyelik bilgilerini güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'membership.plan': plan['name'],
        'membership.planId': plan['id'],
        'membership.startDate': startDate,
        'membership.endDate': endDate,
        'membership.status': 'Active',
      });

      // Ödeme kaydı oluştur
      await FirebaseFirestore.instance.collection('payments').add({
        'userId': user.uid,
        'planId': plan['id'],
        'planName': plan['name'],
        'amount': firstDuration['price'],
        'duration': months,
        'startDate': startDate,
        'endDate': endDate,
        'status': 'Completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${plan['name']} plan purchased successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // İsteğe bağlı: Profil sayfasına dön
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pushReplacementNamed(context, '/profile');
      });
    } catch (e) {
      print('Üyelik satın alma sırasında hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
