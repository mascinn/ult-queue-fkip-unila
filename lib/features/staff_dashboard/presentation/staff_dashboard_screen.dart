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
  String? _filterStatus;

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
    final queues = await _repository.getTodayQueues(
      serviceId: _filterServiceId,
      status: _filterStatus,
    );

    // Cari antrean yang sedang aktif di loket staf ini
    final allToday = await _repository.getTodayQueues();
    final servingAtMyCounter = allToday.where((q) {
      return (q.status == 'called' || q.status == 'in_service') &&
          q.counterName?.trim() == _selectedCounter.trim();
    }).toList();

    if (mounted) {
      setState(() {
        _todayQueues = queues;
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
    // Tentukan serviceId yang akan dipanggil (bisa dari filter atau dari antrean terlama)
    String? targetServiceId = _filterServiceId;

    if (targetServiceId == null) {
      // Cari antrean waiting dengan urutan terkecil secara keseluruhan
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
      // Mainkan suara panggilan otomatis di dashboard petugas
      await _audioService.playCallingAnnouncement(
        queueNumber: called.queueNumber,
        counterName: _selectedCounter,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nomor ${called.queueNumber} berhasil dipanggil ke $_selectedCounter'),
          backgroundColor: AppColors.statusCalled,
        ),
      );
      _loadQueues();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada nomor antrean berikutnya yang menunggu.')),
      );
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
        // Panggil ulang suara
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
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin logout dari akun petugas ULT?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusSkipped, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
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
    final staffUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
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
                const Text(
                  'Dashboard Petugas ULT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  staffUser?.email ?? 'Petugas FKIP Unila',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Selector Loket Aktif
          PopupMenuButton<String>(
            tooltip: 'Ganti Loket',
            initialValue: _selectedCounter,
            onSelected: _changeCounter,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentYellow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textPrimary),
                  const SizedBox(width: 4),
                  Text(
                    _selectedCounter,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textPrimary),
                ],
              ),
            ),
            itemBuilder: (ctx) => AppConstants.defaultCounters.map((counter) {
              return PopupMenuItem<String>(
                value: counter,
                child: Text(counter),
              );
            }).toList(),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadQueues,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. KARTU KONTROL LOKET AKTIF (CURRENT SERVING)
                    _buildActiveCounterControlCard(),

                    const SizedBox(height: 20),

                    // 2. FILTER LAYANAN & STATUS
                    _buildFilterSection(),

                    const SizedBox(height: 16),

                    // 3. DAFTAR ANTREAN HARI INI
                    _buildTodayQueuesHeader(),
                    const SizedBox(height: 10),
                    _buildTodayQueuesList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActiveCounterControlCard() {
    final serving = _myCurrentServing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: serving != null ? AppColors.primary : AppColors.cardBorder,
          width: serving != null ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sensors_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Antrean di $_selectedCounter',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              if (serving != null)
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
          const SizedBox(height: 14),

          if (serving == null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saat ini belum ada antrean yang sedang dilayani di loket ini.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                label: const Text(
                  'PANGGIL ANTREAN BERIKUTNYA',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: _callNext,
              ),
            ),
          ] else ...[
            // Sedang ada tiket yang dipanggil
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    serving.queueNumber,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
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
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
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
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Tombol Aksi Status
            Row(
              children: [
                // Panggil Ulang
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.volume_up_rounded, size: 16),
                    label: const Text('Panggil Ulang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _updateCurrentStatus('called'),
                  ),
                ),
                const SizedBox(width: 8),

                // Mulai Layani / Selesai
                if (serving.isCalled)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusInService,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.person_outline_rounded, size: 16),
                      label: const Text('Mulai Layani', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _updateCurrentStatus('in_service'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCompleted,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Selesai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _updateCurrentStatus('completed'),
                    ),
                  ),

                const SizedBox(width: 8),

                // Lewati (No-Show)
                IconButton(
                  tooltip: 'Lewati Mahasiswa (Tidak Hadir)',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.statusSkippedBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Layanan Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Semua Layanan'),
                selected: _filterServiceId == null,
                onSelected: (selected) {
                  setState(() => _filterServiceId = null);
                  _loadQueues();
                },
              ),
              ..._services.map((s) {
                final isSelected = _filterServiceId == s.id;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('${s.code}: ${s.name}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _filterServiceId = selected ? s.id : null);
                      _loadQueues();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayQueuesHeader() {
    final waitingCount = _todayQueues.where((q) => q.isWaiting).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Daftar Antrean Hari Ini',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.statusWaitingBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$waitingCount Menunggu',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.statusWaiting),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayQueuesList() {
    if (_todayQueues.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_rounded, size: 36, color: AppColors.textMuted),
            SizedBox(height: 8),
            Text(
              'Belum ada antrean untuk filter ini.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _todayQueues.map((ticket) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.getStatusBgColor(ticket.status),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    ticket.queueNumber,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
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
                      '${ticket.studentNpm} • ${ticket.studentStudyProgram}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ticket.service?.name ?? '',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.getStatusBgColor(ticket.status),
                      borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 4),
                  Text(
                    ticket.counterName ?? TimeHelper.formatTimeWib(ticket.createdAt),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
