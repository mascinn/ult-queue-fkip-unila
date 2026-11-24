import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/time_helper.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/audio_tts_service.dart';
import '../../student_queue/data/queue_repository.dart';
import '../../student_queue/models/queue_model.dart';
import '../../student_queue/models/service_model.dart';
import '../../student_queue/presentation/student_home_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final QueueRepository _repository = QueueRepository();
  final AudioTtsService _audioService = AudioTtsService();

  String _selectedCounter = 'Loket 1';
  String? _filterServiceId;

  List<ServiceModel> _services = [];
  List<QueueModel> _todayQueues = [];
  QueueModel? _myCurrentServing;
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _selectedCounter = StorageService.getStaffCounter();
    _loadInitialData();
    _setupRealtime();
  }

  Future<void> _loadInitialData() async {
    final services = await _repository.getServices();
    await _loadQueues();

    if (mounted) {
      setState(() {
        _services = services;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadQueues() async {
    final allToday = await _repository.getTodayQueues();

    // Antrean aktif di loket staf ini
    final servingAtMyCounter = allToday.where((q) {
      return (q.status == 'called' || q.status == 'in_service') &&
          q.counterName?.trim() == _selectedCounter.trim();
    }).toList();

    if (mounted) {
      setState(() {
        _todayQueues = allToday;
        _myCurrentServing = servingAtMyCounter.isNotEmpty ? servingAtMyCounter.first : null;
      });
    }
  }

  void _setupRealtime() {
    _realtimeChannel = _repository.subscribeToAllTodayQueues(
      onChange: () {
        _loadQueues();
      },
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _audioService.stop();
    super.dispose();
  }

  Future<void> _changeCounter(String newCounter) async {
    await StorageService.setStaffCounter(newCounter);
    setState(() {
      _selectedCounter = newCounter;
    });
    _loadQueues();
  }

  Future<void> _callNext() async {
    String? targetServiceId = _filterServiceId;

    if (targetServiceId == null) {
      final waitingList = _todayQueues.where((q) => q.isWaiting).toList();
      if (waitingList.isNotEmpty) {
        targetServiceId = waitingList.first.serviceId;
      } else if (_services.isNotEmpty) {
        targetServiceId = _services.first.id;
      }
    }

    if (targetServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada antrean yang sedang menunggu.')),
      );
      return;
    }

    final called = await _repository.staffCallNextQueue(
      serviceId: targetServiceId,
      counterName: _selectedCounter,
    );

    if (called != null) {
      await _audioService.playCallingAnnouncement(
        queueNumber: called.queueNumber,
        counterName: _selectedCounter,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nomor ${called.queueNumber} berhasil dipanggil ke $_selectedCounter'),
            backgroundColor: AppColors.statusCalled,
          ),
        );
      }
      _loadQueues();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada nomor antrean berikutnya yang menunggu.')),
        );
      }
    }
  }

  Future<void> _callSpecificTicket(QueueModel ticket) async {
    final success = await _repository.staffUpdateQueueStatus(
      queueId: ticket.id,
      newStatus: 'called',
      counterName: _selectedCounter,
    );

    if (success) {
      await _audioService.playCallingAnnouncement(
        queueNumber: ticket.queueNumber,
        counterName: _selectedCounter,
      );

      _loadQueues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nomor ${ticket.queueNumber} dipanggil ke $_selectedCounter'),
            backgroundColor: AppColors.statusCalled,
          ),
        );
      }
    }
  }

  Future<void> _updateCurrentStatus(String newStatus) async {
    if (_myCurrentServing == null) return;

    final success = await _repository.staffUpdateQueueStatus(
      queueId: _myCurrentServing!.id,
      newStatus: newStatus,
      counterName: _selectedCounter,
    );

    if (success) {
      if (newStatus == 'called') {
        await _audioService.playCallingAnnouncement(
          queueNumber: _myCurrentServing!.queueNumber,
          counterName: _selectedCounter,
        );
      }

      _loadQueues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status antrean diperbarui ke: $newStatus'),
            backgroundColor: AppColors.getStatusColor(newStatus),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Petugas ULT?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusSkipped,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingList = _todayQueues.where((q) {
      final isWait = q.isWaiting;
      if (!isWait) return false;
      if (_filterServiceId != null) return q.serviceId == _filterServiceId;
      return true;
    }).toList();

    final waitingCount = _todayQueues.where((q) => q.isWaiting).length;
    final inProgressCount = _todayQueues.where((q) => q.isCalled || q.isInService).length;
    final completedCount = _todayQueues.where((q) => q.isCompleted).length;

    final historyList = _todayQueues.where((q) => q.isCompleted || q.isSkipped).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadQueues,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header Lengkung Ungu Dashboard Petugas (Persis Gambar 1)
                    _buildCurvedHeader(),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. Baris 3 Kartu Statistik (Menunggu, Diproses, Selesai)
                          _buildStatsRow(waitingCount, inProgressCount, completedCount),

                          const SizedBox(height: 18),

                          // 3. Kartu Pilihan Loket Tugas Anda (Loket 1, 2, 3)
                          _buildCounterSelectorCard(),

                          const SizedBox(height: 18),

                          // 4. Kartu Kontrol Utama ("Loket X Siap Melayani" / Panggil Antrean)
                          _buildActiveServingBox(waitingList.length),

                          const SizedBox(height: 24),

                          // 5. Daftar Antrean Menunggu (Filter chips & Empty/Active state)
                          _buildWaitingSection(waitingList),

                          const SizedBox(height: 24),

                          // 6. Riwayat Hari Ini
                          _buildHistorySection(historyList),

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

  /// Header Lengkung Ungu (Persis Gambar 1)
  Widget _buildCurvedHeader() {
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
          padding: const EdgeInsets.fromLTRB(10, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Tombol Kembali
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  // Logo Lingkaran FKIP Unila
                  Container(
                    width: 38,
                    height: 38,
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

                  // Judul & Teks Petugas
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard Petugas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'ULT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Petugas ULT FKIP • STAFF',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Refresh Button
                  IconButton(
                    tooltip: 'Perbarui Data',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    onPressed: _loadQueues,
                  ),

                  // Logout Button
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                    onPressed: _handleLogout,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Capsule: Realtime Aktif
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF4ADE80)),
                    SizedBox(width: 6),
                    Text(
                      'Realtime Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  /// 3 Kartu Statistik (Persis Gambar 1: Menunggu, Diproses, Selesai)
  Widget _buildStatsRow(int waiting, int inProgress, int completed) {
    return Row(
      children: [
        // Menunggu
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.2),
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
                  '$waiting',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Menunggu',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Diproses
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
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
                  '$inProgress',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Diproses',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Selesai
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
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
                  '$completed',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selesai',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Kartu "Loket Tugas Anda" dengan tombol pil (Persis Gambar 1)
  Widget _buildCounterSelectorCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.meeting_room_outlined, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Loket Tugas Anda',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: AppConstants.defaultCounters.map((counter) {
              final isSelected = _selectedCounter == counter;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => _changeCounter(counter),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF7F2FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          counter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Kotak "Loket X Siap Melayani" / Panggil Antrean (Persis Gambar 1)
  Widget _buildActiveServingBox(int waitingCount) {
    final serving = _myCurrentServing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (serving == null) ...[
            Text(
              '$_selectedCounter Siap Melayani',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              waitingCount == 0
                  ? 'Belum ada antrean pada filter terpilih'
                  : 'Tersedia $waitingCount antrean menunggu untuk dipanggil',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Panggil Antrean Berikutnya
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: waitingCount > 0 ? AppColors.primary : const Color(0xFFE2E8F0),
                  foregroundColor: waitingCount > 0 ? Colors.white : const Color(0xFF94A3B8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                label: const Text(
                  'Panggil Antrean Berikutnya',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: waitingCount > 0 ? _callNext : null,
              ),
            ),
          ] else ...[
            // Saat Ada Antrean yang Sedang Diproses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sedang Dilayani di $_selectedCounter',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.getStatusBgColor(serving.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    serving.statusDisplayIndonesian,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getStatusColor(serving.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    serving.queueNumber,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serving.studentName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NPM: ${serving.studentNpm}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        serving.studentStudyProgram,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serving.service?.name ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tombol Aksi Panggilan
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.volume_up_rounded, size: 16),
                    label: const Text('Panggil Ulang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _updateCurrentStatus('called'),
                  ),
                ),
                const SizedBox(width: 8),

                if (serving.isCalled)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusInService,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_outline_rounded, size: 16),
                      label: const Text('Mulai Layani', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _updateCurrentStatus('in_service'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCompleted,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Selesai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _updateCurrentStatus('completed'),
                    ),
                  ),

                const SizedBox(width: 8),

                IconButton(
                  tooltip: 'Lewati Mahasiswa (Tidak Hadir)',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.statusSkippedBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.person_off_outlined, color: AppColors.statusSkipped, size: 18),
                  onPressed: () => _updateCurrentStatus('skipped'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Section "Daftar Antrean Menunggu" (Persis Gambar 1)
  Widget _buildWaitingSection(List<QueueModel> waitingList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Antrean Menunggu (${waitingList.length})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Filter Pills: [Semua] [A • KKN] [B • Wisuda] [C • Surat] [D • Lainnya]
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua',
                isSelected: _filterServiceId == null,
                onTap: () {
                  setState(() => _filterServiceId = null);
                },
              ),
              ..._services.map((s) {
                final isSelected = _filterServiceId == s.id;
                final shortName = s.name.split(' ').take(2).join(' ').replaceAll('Pengurusan ', '').replaceAll('Pengajuan ', '');

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildFilterChip(
                    label: '${s.code} • $shortName',
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _filterServiceId = isSelected ? null : s.id);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Empty State (Persis Gambar 1)
        if (waitingList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
                SizedBox(height: 12),
                Text(
                  'Tidak Ada Antrean Menunggu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Antrean baru dari mahasiswa akan muncul secara otomatis di sini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          // Daftar Kartu Antrean Menunggu
          ...waitingList.map((ticket) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        ticket.queueNumber,
                        style: const TextStyle(
                          fontSize: 16,
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
                          ticket.studentName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${ticket.studentNpm} • ${ticket.studentStudyProgram}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          ticket.service?.name ?? '',
                          style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _callSpecificTicket(ticket),
                    child: const Text('Panggil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Section "Riwayat Hari Ini"
  Widget _buildHistorySection(List<QueueModel> historyList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat Hari Ini (${historyList.length})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        if (historyList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Center(
              child: Text(
                'Belum ada riwayat pelayanan hari ini.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...historyList.map((ticket) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.getStatusBgColor(ticket.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        ticket.queueNumber,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getStatusColor(ticket.status),
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
                          ticket.studentName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${ticket.counterName ?? 'Loket'} • ${TimeHelper.formatTimeWib(ticket.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getStatusBgColor(ticket.status),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      ticket.statusDisplayIndonesian,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getStatusColor(ticket.status),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
