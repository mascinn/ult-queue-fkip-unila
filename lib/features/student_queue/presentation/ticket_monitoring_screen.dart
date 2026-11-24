import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/time_helper.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/audio_tts_service.dart';
import '../data/queue_repository.dart';
import '../models/queue_model.dart';
import 'student_home_screen.dart';

class TicketMonitoringScreen extends StatefulWidget {
  final String ticketId;

  const TicketMonitoringScreen({super.key, required this.ticketId});

  @override
  State<TicketMonitoringScreen> createState() => _TicketMonitoringScreenState();
}

class _TicketMonitoringScreenState extends State<TicketMonitoringScreen> {
  final QueueRepository _repository = QueueRepository();
  final AudioTtsService _audioService = AudioTtsService();

  QueueModel? _ticket;
  int _waitingAhead = 0;
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  bool _hasAnnouncedCalling = false;

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
    _setupRealtimeSubscription();
  }

  Future<void> _loadTicketDetails() async {
    final ticket = await _repository.getTicketById(widget.ticketId);
    if (ticket != null) {
      final ahead = await _repository.countWaitingAhead(
        ticket.serviceId,
        ticket.sequenceNumber,
      );

      if (mounted) {
        setState(() {
          _ticket = ticket;
          _waitingAhead = ahead;
          _isLoading = false;
        });

        // Cek jika status langsung 'called' saat pertama buka
        if (ticket.isCalled && !_hasAnnouncedCalling) {
          _triggerCallingAlert(ticket);
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    _realtimeChannel = _repository.subscribeToTicket(
      ticketId: widget.ticketId,
      onUpdate: (updatedTicket) {
        if (!mounted) return;

        final previousStatus = _ticket?.status;

        setState(() {
          _ticket = updatedTicket;
        });

        // Trigger alert jika status berubah menjadi 'called'
        if (updatedTicket.isCalled && previousStatus != 'called') {
          _triggerCallingAlert(updatedTicket);
        }

        // Muat ulang antrean di depan
        _repository
            .countWaitingAhead(updatedTicket.serviceId, updatedTicket.sequenceNumber)
            .then((ahead) {
          if (mounted) setState(() => _waitingAhead = ahead);
        });
      },
    );
  }

  void _triggerCallingAlert(QueueModel ticket) {
    _hasAnnouncedCalling = true;
    final counter = ticket.counterName ?? 'Loket ULT';

    // 1. Suara & Getar
    _audioService.playCallingAnnouncement(
      queueNumber: ticket.queueNumber,
      counterName: counter,
    );

    // 2. Dialog Modal Visual Mencolok
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.statusCalledBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: AppColors.statusCalled, size: 48),
            ),
            const SizedBox(height: 18),
            const Text(
              'GILIRAN ANDA TIBA!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nomor Antrean Anda:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              ticket.queueNumber,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'SILAKAN MENUJU $counter',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Harap segera menuju loket membawa berkas persyaratan Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _audioService.stop();
                Navigator.of(ctx).pop();
              },
              child: const Text('Saya Menuju Loket Sekarang'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _audioService.stop();
    super.dispose();
  }

  Future<void> _clearAndGoHome() async {
    await StorageService.clearActiveTicketId();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ticket == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Detail Tiket'), backgroundColor: AppColors.primary),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.statusSkipped),
              const SizedBox(height: 16),
              const Text('Data tiket antrean tidak ditemukan.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _clearAndGoHome,
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        ),
      );
    }

    final ticket = _ticket!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Tiket Antrean ULT FKIP',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui Data',
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
            onPressed: _loadTicketDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // KARTU TIKET ELEKTRONIK
            _buildTicketCard(ticket),

            const SizedBox(height: 20),

            // KARTU ESTIMASI & STATUS ANTREAN
            _buildStatusInfoCard(ticket),

            const SizedBox(height: 24),

            // TOMBOL AKSI
            if (ticket.isCompleted || ticket.isSkipped)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Selesai & Tutup Tiket Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _clearAndGoHome,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: const Text('Kembali ke Beranda (Tetap Pantau)'),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
                      (route) => false,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(QueueModel ticket) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Kartu
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        AppConstants.facultyName,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  ticket.service?.name ?? 'Pelayanan ULT FKIP',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Giant Queue Number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ticket.queueNumber,
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.getStatusBgColor(ticket.status),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.getStatusColor(ticket.status).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.getStatusColor(ticket.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ticket.statusDisplayIndonesian.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.getStatusColor(ticket.status),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Identitas Mahasiswa
                _buildInfoRow('Nama', ticket.studentName),
                _buildInfoRow('NPM', ticket.studentNpm),
                _buildInfoRow('Program Studi', ticket.studentStudyProgram),
                _buildInfoRow(
                  'Waktu Ambil',
                  TimeHelper.formatTimeWib(ticket.createdAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfoCard(QueueModel ticket) {
    if (ticket.isCalled || ticket.isInService) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.statusCalledBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.statusCalled.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.volume_up_rounded, color: AppColors.statusCalled, size: 32),
            const SizedBox(height: 10),
            Text(
              ticket.isCalled ? 'PANGGILAN LOKET AKTIF' : 'SEDANG DILAYANI DI LOKET',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.statusCalled,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Silakan menuju: ${ticket.counterName ?? "Loket Pelayanan ULT"}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (ticket.isWaiting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_rounded, size: 18, color: AppColors.statusWaiting),
                SizedBox(width: 8),
                Text(
                  'Sedang Dalam Antrean',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$_waitingAhead',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const Text(
              'Antrean di depan Anda saat ini',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tetap aktifkan layar dan volume suara HP Anda. Aplikasi akan berbunyi dan bergetar saat nomor Anda dipanggil.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (ticket.isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.statusCompletedBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.statusCompleted, size: 36),
            SizedBox(height: 8),
            Text(
              'Pelayanan Telah Selesai',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.statusCompleted),
            ),
            SizedBox(height: 4),
            Text(
              'Terima kasih telah memanfaatkan layanan Unit Layanan Terpadu FKIP Unila.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
