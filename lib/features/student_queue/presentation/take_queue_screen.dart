import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../data/queue_repository.dart';
import '../models/service_model.dart';
import 'ticket_monitoring_screen.dart';

class TakeQueueScreen extends StatefulWidget {
  const TakeQueueScreen({super.key});

  @override
  State<TakeQueueScreen> createState() => _TakeQueueScreenState();
}

class _TakeQueueScreenState extends State<TakeQueueScreen> {
  final _formKey = GlobalKey<FormState>();
  final QueueRepository _repository = QueueRepository();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _npmController = TextEditingController();
  String? _selectedProdi;
  ServiceModel? _selectedService;

  List<ServiceModel> _services = [];
  bool _isLoadingServices = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Ambil data profil tersimpan dari storage jika ada
    final cachedProfile = StorageService.getStudentProfile();
    if (cachedProfile['name']?.isNotEmpty == true) {
      _nameController.text = cachedProfile['name']!;
    }
    if (cachedProfile['npm']?.isNotEmpty == true) {
      _npmController.text = cachedProfile['npm']!;
    }
    if (cachedProfile['prodi']?.isNotEmpty == true) {
      _selectedProdi = cachedProfile['prodi'];
    }

    // 2. Ambil master layanan
    final services = await _repository.getServices();
    if (mounted) {
      setState(() {
        _services = services;
        if (_services.isNotEmpty) {
          _selectedService = _services.first;
        }
        _isLoadingServices = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _npmController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih salah satu jenis layanan.'),
          backgroundColor: AppColors.statusSkipped,
        ),
      );
      return;
    }

    final studentName = _nameController.text.trim();
    final studentNpm = _npmController.text.trim();
    final studyProgram = _selectedProdi ?? AppConstants.fkipStudyPrograms.first;

    // Tampilkan dialog konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.helpCircle, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Konfirmasi Antrean', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pastikan data yang Anda masukkan sudah benar sebelum mengambil nomor antrean:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _buildConfirmRow('Layanan', _selectedService!.name),
            _buildConfirmRow('Nama', studentName),
            _buildConfirmRow('NPM', studentNpm),
            _buildConfirmRow('Program Studi', studyProgram),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Periksa Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Ambil Nomor'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final newTicket = await _repository.takeQueueTicket(
        serviceId: _selectedService!.id,
        studentName: studentName,
        studentNpm: studentNpm,
        studyProgram: studyProgram,
      );

      // Simpan tiket aktif dan profil ke storage lokal
      await StorageService.setActiveTicketId(newTicket.id);
      await StorageService.saveStudentProfile(
        name: studentName,
        npm: studentNpm,
        prodi: studyProgram,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nomor antrean ${newTicket.queueNumber} berhasil diambil!'),
          backgroundColor: AppColors.statusCompleted,
        ),
      );

      // Arahkan ke layar monitoring tiket
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TicketMonitoringScreen(ticketId: newTicket.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Pengambilan Antrean Gagal', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(errorMsg, style: const TextStyle(fontSize: 14)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
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
        title: const Text(
          'Ambil Antrean ULT',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoadingServices
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: Pilih Jenis Layanan
                    const Row(
                      children: [
                        Icon(LucideIcons.layers, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Langkah 1: Pilih Jenis Layanan',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._services.map((service) {
                      final isSelected = _selectedService?.id == service.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedService = service),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryLight : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.cardBorder,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    service.code,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppColors.primary,
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
                                      service.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (service.description != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        service.description!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(LucideIcons.checkCircle2, color: AppColors.primary, size: 22),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Step 2: Form Data Diri Mahasiswa
                    const Row(
                      children: [
                        Icon(LucideIcons.userCheck, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Langkah 2: Data Mahasiswa FKIP',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Nama Lengkap
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap Mahasiswa',
                        hintText: 'Contoh: Ahmad Fauzi',
                        prefixIcon: const Icon(LucideIcons.user, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama lengkap wajib diisi';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // NPM
                    TextFormField(
                      controller: _npmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'NPM (Nomor Pokok Mahasiswa)',
                        hintText: 'Contoh: 2113025001',
                        prefixIcon: const Icon(LucideIcons.creditCard, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'NPM wajib diisi';
                        }
                        if (val.trim().length < 8) {
                          return 'NPM minimal 8 digit angka';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Program Studi
                    DropdownButtonFormField<String>(
                      value: _selectedProdi,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Program Studi FKIP',
                        prefixIcon: const Icon(LucideIcons.graduationCap, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                      hint: const Text('Pilih Program Studi'),
                      items: AppConstants.fkipStudyPrograms.map((prodi) {
                        return DropdownMenuItem<String>(
                          value: prodi,
                          child: Text(
                            prodi,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedProdi = val);
                      },
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Silakan pilih program studi Anda';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Tombol Submit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(LucideIcons.ticket, size: 20),
                        label: Text(
                          _isSubmitting ? 'Memproses Nomor Antrean...' : 'Konfirmasi & Ambil Nomor',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSubmitting ? null : _submitTicket,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
