// lib/screens/reservations/reservations_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/service_provider.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  _ReservationsScreenState createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _reservations = [];
  Map<String, dynamic>?
      _selectedClass; // Kullanıcının seçtiği ders (argüman olarak gelir)
  DateTime _selectedDate = DateTime.now(); // Varsayılan olarak bugün
  bool _isCreatingReservation = false; // Rezervasyon oluşturma durumu

  @override
  void initState() {
    super.initState();
    // Sayfa yüklendikten sonra argümanları kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkArguments();
      _loadReservations();
    });
  }

  // Sayfa argümanlarını kontrol et
  void _checkArguments() {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      setState(() {
        _selectedClass = arguments;
        // Eğer argüman ile geldiyse, o dersin gününü seçili tarih olarak ayarla
        final dayName = _selectedClass!['day'];
        if (dayName != null && dayName.isNotEmpty) {
          _selectedDate = _getDateFromDayName(dayName);
        }
      });
      print('Seçilen ders: ${_selectedClass?['name']}');
    } else {
      print('Herhangi bir ders seçilmedi');
    }
  }

  // Gün adından tarih oluşturma
  DateTime _getDateFromDayName(String dayName) {
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final today = DateTime.now();
    final todayWeekday = today.weekday; // 1 = Monday, 7 = Sunday

    final targetWeekday = daysOfWeek.indexOf(dayName) + 1;
    final difference = targetWeekday - todayWeekday;

    // Eğer hedef gün bugünden önceyse, gelecek haftanın o gününü al
    final daysToAdd = difference < 0 ? difference + 7 : difference;
    return today.add(Duration(days: daysToAdd));
  }

  // Firestore'dan kullanıcının rezervasyonlarını yükleme
  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: false)
          .get();

      print('Rezervasyonlar yükleniyor... Bulunan: ${snapshot.docs.length}');

      final List<Map<String, dynamic>> reservations = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Firestore'dan gelen Timestamp'i DateTime'a çevirme
        DateTime date = DateTime.now();
        if (data['date'] != null && data['date'] is Timestamp) {
          date = (data['date'] as Timestamp).toDate();
        }

        return {
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'classId': data['classId'] ?? '',
          'className': data['className'] ?? '',
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'day': data['day'] ?? '',
          'date': date,
          'status': data['status'] ?? 'Pending',
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();

      setState(() {
        _reservations = reservations;
        _isLoading = false;
      });
    } catch (e) {
      print('Rezervasyonlar yüklenirken hata: $e');
      setState(() {
        _errorMessage = 'Rezervasyonlar yüklenirken bir hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  // Rezervasyon oluşturma
  Future<void> _createReservation() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir ders seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingReservation = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      // Rezervasyon verisini hazırla
      final reservationData = {
        'userId': user.uid,
        'classId': _selectedClass!['id'],
        'className': _selectedClass!['name'],
        'startTime': _selectedClass!['startTime'],
        'endTime': _selectedClass!['endTime'],
        'day': _selectedClass!['day'],
        'date': _selectedDate,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Firestore'a rezervasyon ekle
      final docRef = await FirebaseFirestore.instance
          .collection('reservations')
          .add(reservationData);

      print('Rezervasyon oluşturuldu: ${docRef.id}');

      // Sınıfın katılımcı sayısını artır
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(_selectedClass!['id'])
          .update({'enrolled': FieldValue.increment(1)});

      // Başarılı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rezervasyon başarıyla oluşturuldu!'),
          backgroundColor: Colors.green,
        ),
      );

      // Rezervasyonları yenile
      _loadReservations();
    } catch (e) {
      print('Rezervasyon oluşturulurken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rezervasyon oluşturulurken bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreatingReservation = false;
      });
    }
  }

  // Rezervasyon iptal etme
  Future<void> _cancelReservation(String reservationId, String classId) async {
    try {
      // Rezervasyonu güncelle
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({'status': 'Cancelled'});

      // Sınıfın katılımcı sayısını azalt
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .update({'enrolled': FieldValue.increment(-1)});

      // Başarılı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rezervasyon iptal edildi'),
          backgroundColor: Colors.green,
        ),
      );

      // Rezervasyonları yenile
      _loadReservations();
    } catch (e) {
      print('Rezervasyon iptal edilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rezervasyon iptal edilirken bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Reservations',
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
              ? _buildErrorMessage()
              : _buildReservationsContent(),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        selectedItemColor: Colors.blue,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/classes');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/qr-code');
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.qr_code, color: Colors.white),
      ),
    );
  }

  // Hata mesajı widget'ı
  Widget _buildErrorMessage() {
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadReservations,
              child: Text(
                'Tekrar Dene',
                style: GoogleFonts.ubuntu(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ana içerik widget'ı
  Widget _buildReservationsContent() {
    // Eğer bir ders seçilmişse, rezervasyon oluşturma ekranını göster
    if (_selectedClass != null) {
      return _buildCreateReservationView();
    }

    // Seçili ders yoksa, mevcut rezervasyonları göster
    return _reservations.isEmpty
        ? _buildEmptyReservationsMessage()
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _reservations.length,
            itemBuilder: (context, index) {
              return _buildReservationCard(_reservations[index]);
            },
          );
  }

  // Boş rezervasyonlar mesajı
  Widget _buildEmptyReservationsMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Henüz rezervasyon yapmadınız',
            style: GoogleFonts.ubuntu(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bir ders seçerek rezervasyon yapabilirsiniz',
            style: GoogleFonts.ubuntu(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/classes');
            },
            child: Text(
              'Derslere Göz At',
              style: GoogleFonts.ubuntu(),
            ),
          ),
        ],
      ),
    );
  }

  // Rezervasyon kartı
  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    // Tarih formatı
    final date = reservation['date'] as DateTime;
    final formattedDate = DateFormat('MMMM d, yyyy').format(date);

    // Durum rengi
    Color statusColor;
    switch (reservation['status']) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Pending':
        statusColor = Colors.orange;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation['className'],
                      style: GoogleFonts.ubuntu(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reservation['day']}, $formattedDate',
                      style: GoogleFonts.ubuntu(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    reservation['status'],
                    style: GoogleFonts.ubuntu(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${reservation['startTime']} - ${reservation['endTime']}',
                  style: GoogleFonts.ubuntu(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (reservation['status'] != 'Cancelled')
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // İptal iletişim kutusu
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Cancel Reservation',
                            style:
                                GoogleFonts.ubuntu(fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'Are you sure you want to cancel this reservation?',
                            style: GoogleFonts.ubuntu(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'No',
                                style: GoogleFonts.ubuntu(),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _cancelReservation(
                                  reservation['id'],
                                  reservation['classId'],
                                );
                              },
                              child: Text(
                                'Yes',
                                style: GoogleFonts.ubuntu(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Rezervasyon oluşturma ekranı
  Widget _buildCreateReservationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rezervasyon detayları kartı
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Text(
                    'Reservation Details',
                    style: GoogleFonts.ubuntu(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ders adı
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Class',
                              style: GoogleFonts.ubuntu(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _selectedClass!['name'],
                              style: GoogleFonts.ubuntu(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Gün ve Saat
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: GoogleFonts.ubuntu(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${_selectedClass!['day']}, ${_selectedClass!['startTime']} - ${_selectedClass!['endTime']}',
                              style: GoogleFonts.ubuntu(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tarih seçimi
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: GoogleFonts.ubuntu(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              DateFormat('MMMM d, yyyy').format(_selectedDate),
                              style: GoogleFonts.ubuntu(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        child: Text(
                          'Change',
                          style: GoogleFonts.ubuntu(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rezervasyon oluşturma butonu
          SizedBox(
            width: double.infinity,
            child: _isCreatingReservation
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _createReservation,
                    child: Text(
                      'Confirm Reservation',
                      style: GoogleFonts.ubuntu(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // İptal butonu
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedClass = null;
                });
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.ubuntu(
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Mevcut rezervasyonlar başlığı
          if (_reservations.isNotEmpty) ...[
            Text(
              'Your Current Reservations',
              style: GoogleFonts.ubuntu(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Mevcut rezervasyonlar listesi
            ..._reservations
                .map((reservation) => _buildReservationCard(reservation)),
          ],
        ],
      ),
    );
  }
}
