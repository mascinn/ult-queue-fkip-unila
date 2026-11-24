import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/time_helper.dart';
import '../../../core/services/storage_service.dart';
import '../data/queue_repository.dart';
import '../models/queue_model.dart';
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
  List<QueueModel> _currentlyServing = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadCurrentlyServing();
    _setupRealtime();
  }

  Future<void> _loadCurrentlyServing() async {
    final list = await _repository.getCurrentlyServingQueues();
    if (mounted) {
      setState(() {
        _currentlyServing = list;
        _isLoading = false;
      });
    }
  }

  void _setupRealtime() {
    _realtimeChannel = _repository.subscribeToAllTodayQueues(
      onChange: () {
        _loadCurrentlyServing();
      },
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
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

    // Jika tidak ada di local storage, tampilkan dialog input NPM
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Login Petugas ULT',
            icon: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.accentYellow),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginStaffScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCurrentlyServing,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Sambutan & Jadwal Operasional
              _buildOperationalBanner(),

              const SizedBox(height: 20),

              // 2. Live Papan Loket ("Sedang Dilayani Saat Ini")
              _buildLiveCountersSection(),

              const SizedBox(height: 24),

              // 3. Tombol Aksi Utama Mahasiswa
              _buildMainActionButtons(),

              const SizedBox(height: 28),

              // 4. Daftar Kategori Layanan Administrasi FKIP
              _buildServicesGuideSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationalBanner() {
    final isOpen = TimeHelper.isWithinStandardHours();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOpen ? AppColors.primary.withOpacity(0.25) : AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isOpen ? AppColors.statusCompletedBg : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOpen ? AppColors.statusCompleted : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      TimeHelper.getOperatingStatusBadge(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? AppColors.statusCompleted : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  TimeHelper.formatTimeWib(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Selamat Datang di ULT FKIP Unila',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            TimeHelper.getOperatingStatusSubtitle(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOpen ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Jadwal: ${TimeHelper.getOperatingHoursDescription()}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCountersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sensors_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Sedang Dilayani di Loket',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        else
          Row(
            children: AppConstants.defaultCounters.map((counterName) {
              // Cari antrean aktif di loket ini
              final activeForCounter = _currentlyServing.where(
                (q) => q.counterName?.trim() == counterName.trim(),
              ).toList();

              final currentTicket = activeForCounter.isNotEmpty ? activeForCounter.first : null;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: currentTicket != null ? AppColors.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: currentTicket != null
                          ? AppColors.primary.withOpacity(0.4)
                          : AppColors.cardBorder,
                      width: currentTicket != null ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        counterName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: currentTicket != null ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentTicket?.queueNumber ?? '---',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: currentTicket != null ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentTicket != null
                            ? (currentTicket.isCalled ? 'Dipanggil' : 'Dilayani')
                            : 'Kosong',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: currentTicket != null
                              ? AppColors.statusCalled
                              : AppColors.textMuted,
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

  Widget _buildMainActionButtons() {
    final isOpen = TimeHelper.isWithinStandardHours();

    return Column(
      children: [
        // Tombol Ambil Antrean (Utama)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isOpen ? AppColors.primary : const Color(0xFF94A3B8),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.confirmation_number_rounded, size: 22),
            label: Text(
              isOpen ? 'Ambil Nomor Antrean' : 'Pelayanan Tutup (Buka 08:00 WIB)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (isOpen) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TakeQueueScreen()),
                );
              } else {
                _showClosedNoticeDialog();
              }
            },
          ),
        ),

        const SizedBox(height: 12),

        // Tombol Cek Antrean Saya
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text(
              'Cek Status Antrean Saya',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            onPressed: _checkMyTicket,
          ),
        ),
      ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jadwal Resmi Pelayanan:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppConstants.operationalDays}, ${AppConstants.operationalHours}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
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

  Widget _buildServicesGuideSection() {
    final services = [
      {'code': 'A', 'name': 'Pengurusan Berkas KKN', 'desc': 'Validasi & administrasi KKN FKIP'},
      {'code': 'B', 'name': 'Pengajuan Berkas Wisuda', 'desc': 'Pemeriksaan berkas yudisium'},
      {'code': 'C', 'name': 'Pengurusan Surat Administrasi', 'desc': 'Surat aktif kuliah, izin riset'},
      {'code': 'D', 'name': 'Layanan Administrasi Lainnya', 'desc': 'Legalisasi ijazah & transkrip'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Layanan Administrasi ULT FKIP',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...services.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        s['code']!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
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
                          s['name']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s['desc']!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
