import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/time_helper.dart';
import '../../../core/services/storage_service.dart';
import '../data/queue_repository.dart';
import '../models/queue_model.dart';
import '../models/service_model.dart';
import 'take_queue_screen.dart';
import 'ticket_monitoring_screen.dart';
import '../../auth/presentation/login_staff_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final QueueRepository _repository = QueueRepository();

  List<ServiceModel> _services = [];
  List<QueueModel> _currentlyServing = [];
  List<QueueModel> _todayQueues = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _setupRealtime();
    _startClock();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _loadAllData() async {
    final servicesFuture = _repository.getServices();
    final servingFuture = _repository.getCurrentlyServingQueues();
    final todayQueuesFuture = _repository.getTodayQueues();

    final results = await Future.wait([
      servicesFuture,
      servingFuture,
      todayQueuesFuture,
    ]);

    if (mounted) {
      setState(() {
        _services = results[0] as List<ServiceModel>;
        _currentlyServing = results[1] as List<QueueModel>;
        _todayQueues = results[2] as List<QueueModel>;
        _isLoading = false;
      });
    }
  }

  void _setupRealtime() {
    _realtimeChannel = _repository.subscribeToAllTodayQueues(
      onChange: () {
        _loadAllData();
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  String _formatDateWib(DateTime dt) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  String _formatTimeWib(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s WIB';
  }

  int _getWaitingCountForService(String serviceId) {
    return _todayQueues.where((q) => q.serviceId == serviceId && q.status == 'waiting').length;
  }

  int _getRemainingQuotaForService(ServiceModel s) {
    final takenToday = _todayQueues.where((q) => q.serviceId == s.id).length;
    final remaining = s.quotaPerDay - takenToday;
    return remaining < 0 ? 0 : remaining;
  }

  void _checkMyTicket() async {
    final activeTicketId = StorageService.getActiveTicketId();

    if (activeTicketId != null && activeTicketId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketMonitoringScreen(ticketId: activeTicketId),
        ),
      );
      return;
    }

    final npmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cek Antrean Mahasiswa',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan NPM Anda untuk mencari tiket antrean hari ini:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: npmController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Contoh: 2113025001',
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                filled: true,
                fillColor: AppColors.primaryLight.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final npm = npmController.text.trim();
              if (npm.isEmpty) return;

              Navigator.of(ctx).pop();
              final ticket = await _repository.getTodayActiveTicketByNpm(npm);

              if (!mounted) return;
              if (ticket != null) {
                await StorageService.setActiveTicketId(ticket.id);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TicketMonitoringScreen(ticketId: ticket.id),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tidak ada tiket antrean aktif untuk NPM tersebut hari ini.'),
                    backgroundColor: AppColors.statusSkipped,
                  ),
                );
              }
            },
            child: const Text('Cari Tiket'),
          ),
        ],
      ),
    );
  }

  void _onServiceSelected(ServiceModel service) {
    final isOpen = TimeHelper.isWithinStandardHours();
    if (!isOpen) {
      _showClosedNoticeDialog();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TakeQueueScreen(initialServiceId: service.id),
      ),
    );
  }

  void _showClosedNoticeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.schedule_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Pelayanan Tutup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unit Layanan Terpadu (ULT) FKIP Unila saat ini berada di luar jam operasional resmi.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jadwal Resmi Pelayanan:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${AppConstants.operationalDays}, ${AppConstants.operationalHours}',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header Lengkung Ungu Khas FKIP Unila (Gambar 2)
                    _buildCurvedPurpleHeader(),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. Banner Kartu Status Operasional
                          _buildOperationalCard(),

                          const SizedBox(height: 20),

                          // 3. Sedang Dilayani di Loket (3 Cards)
                          _buildLiveCountersSection(),

                          const SizedBox(height: 24),

                          // 4. Pilih Layanan Administrasi (List Cards A, B, C, D)
                          _buildServicesSection(),

                          const SizedBox(height: 20),

                          // 5. Tombol Cek Status Antrean Saya
                          _buildCheckTicketButton(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Header Lengkung Ungu (Persis Gambar 2)
  Widget _buildCurvedPurpleHeader() {
    final isOpen = TimeHelper.isWithinStandardHours();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              // Baris Bar Atas (Logo, Judul, Refresh, dan Tombol Login Petugas)
              Row(
                children: [
                  // Logo FKIP Unila
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_fkip.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Judul & Tagline
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Antrian ULT FKIP',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'FKIP Universitas Lampung',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tombol Refresh
                  IconButton(
                    tooltip: 'Perbarui Data',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    onPressed: _loadAllData,
                  ),

                  // Tombol Kapsul "Login Petugas"
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginStaffScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Login Petugas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Kartu Kaca Transparan Jam & Status Operasional
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDateWib(_currentTime),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatTimeWib(_currentTime),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOpen ? 'Layanan Buka' : 'Layanan Tutup',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOpen ? AppColors.statusCompleted : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu Status Operasional (Notice Card)
  Widget _buildOperationalCard() {
    final isOpen = TimeHelper.isWithinStandardHours();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isOpen ? AppColors.statusCompletedBg : const Color(0xFFFDE8E8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen ? Icons.check_circle_outline_rounded : Icons.access_time_rounded,
              color: isOpen ? AppColors.statusCompleted : const Color(0xFFE02424),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'Pelayanan ULT Sedang Berlangsung' : 'Di Luar Jam Operasional ULT',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOpen
                      ? 'Petugas loket ULT FKIP Unila siap melayani administrasi mahasiswa hingga pukul 16:00 WIB.'
                      : 'Pelayanan administrasi ULT FKIP Unila dibuka setiap Senin–Jumat pukul 08:00–16:00 WIB. Silakan kembali pada jam layanan.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section "Sedang Dilayani di Loket" (3 Cards Horizontal)
  Widget _buildLiveCountersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sedang Dilayani di Loket',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF2E7D32)),
                  SizedBox(width: 6),
                  Text(
                    'Realtime Aktif',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: AppConstants.defaultCounters.map((counterName) {
            final activeForCounter = _currentlyServing.where(
              (q) => q.counterName?.trim() == counterName.trim(),
            ).toList();

            final currentTicket = activeForCounter.isNotEmpty ? activeForCounter.first : null;
            final isServing = currentTicket != null;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isServing ? AppColors.primary.withOpacity(0.4) : AppColors.cardBorder,
                    width: isServing ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      counterName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentTicket?.queueNumber ?? '----',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isServing ? AppColors.primary : AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isServing ? 'Melayani' : 'Tersedia',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isServing ? FontWeight.bold : FontWeight.w500,
                        color: isServing ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Section "Pilih Layanan Administrasi" (Persis Gambar 2)
  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pilih Layanan Administrasi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${_services.length} Layanan',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ..._services.map((s) {
          final waitingCount = _getWaitingCountForService(s.id);
          final remainingQuota = _getRemainingQuotaForService(s);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _onServiceSelected(s),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris Atas: Kode Avatar, Nama, Deskripsi, Panah Kanan
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E5F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                s.code,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  s.description ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFFCE93D8),
                            size: 20,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Garis Tipis Pemisah
                      Container(
                        height: 1,
                        color: const Color(0xFFF1F5F9),
                      ),

                      const SizedBox(height: 10),

                      // Baris Bawah: Tiket Menunggu & Sisa Kuota
                      Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$waitingCount menunggu',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Sisa $remainingQuota/${s.quotaPerDay}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Tombol Akses Cek Status Antrean Saya
  Widget _buildCheckTicketButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.search_rounded, size: 20),
        label: const Text(
          'Cek Status Antrean Saya',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        onPressed: _checkMyTicket,
      ),
    );
  }
}
