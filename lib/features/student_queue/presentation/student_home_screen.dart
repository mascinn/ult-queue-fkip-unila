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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              AppConstants.appTagline,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.85),
              ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen ? AppColors.statusCompletedBg : AppColors.statusWaitingBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOpen ? AppColors.statusCompleted : AppColors.statusWaiting,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      TimeHelper.getOperatingStatusBadge(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? AppColors.statusCompleted : AppColors.statusWaiting,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                TimeHelper.formatTimeWib(DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Selamat Datang di Unit Layanan Terpadu FKIP',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jam Pelayanan: ${TimeHelper.getOperatingHoursDescription()}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
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
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: currentTicket != null ? AppColors.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: currentTicket != null
                          ? AppColors.primary.withOpacity(0.5)
                          : AppColors.cardBorder,
                      width: currentTicket != null ? 1.5 : 1,
                    ),
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
    return Column(
      children: [
        // Tombol Ambil Antrean (Utama)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.confirmation_number_rounded, size: 22),
            label: const Text(
              'Ambil Nomor Antrean',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TakeQueueScreen()),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Tombol Cek Antrean Saya
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text(
              'Cek Antrean Saya',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            onPressed: _checkMyTicket,
          ),
        ),
      ],
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
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...services.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        s['code']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['name']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
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
