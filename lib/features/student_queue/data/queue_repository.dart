import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_model.dart';
import '../models/counter_model.dart';
import '../models/queue_model.dart';

class QueueRepository {
  final SupabaseClient _client;

  QueueRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Mengambil daftar master jenis layanan aktif
  Future<List<ServiceModel>> getServices() async {
    try {
      final response = await _client
          .from('services')
          .select()
          .eq('is_active', true)
          .order('code', ascending: true);

      return (response as List).map((json) => ServiceModel.fromMap(json)).toList();
    } catch (e) {
      developer.log('Error fetching services: $e', name: 'QueueRepository');
      // Fallback data default jika database belum diisi
      return [
        ServiceModel(
          id: '11111111-1111-1111-1111-111111111111',
          code: 'A',
          name: 'Pengurusan Berkas KKN',
          description: 'Validasi berkas pendaftaran dan administrasi KKN FKIP',
          quotaPerDay: 50,
        ),
        ServiceModel(
          id: '22222222-2222-2222-2222-222222222222',
          code: 'B',
          name: 'Pengajuan Berkas Wisuda',
          description: 'Pemeriksaan berkas yudisium dan pendaftaran wisuda',
          quotaPerDay: 50,
        ),
        ServiceModel(
          id: '33333333-3333-3333-3333-333333333333',
          code: 'C',
          name: 'Pengurusan Surat Administrasi',
          description: 'Surat keterangan aktif kuliah, izin riset, surat pengantar',
          quotaPerDay: 75,
        ),
        ServiceModel(
          id: '44444444-4444-4444-4444-444444444444',
          code: 'D',
          name: 'Layanan Administrasi Lainnya',
          description: 'Legalisasi ijazah/transkrip dan informasi administrasi umum',
          quotaPerDay: 50,
        ),
      ];
    }
  }

  /// Mengambil daftar loket pelayanan ULT
  Future<List<CounterModel>> getCounters() async {
    try {
      final response = await _client
          .from('counters')
          .select()
          .eq('is_active', true)
          .order('id', ascending: true);

      return (response as List).map((json) => CounterModel.fromMap(json)).toList();
    } catch (e) {
      developer.log('Error fetching counters: $e', name: 'QueueRepository');
      return [
        CounterModel(id: 1, name: 'Loket 1'),
        CounterModel(id: 2, name: 'Loket 2'),
        CounterModel(id: 3, name: 'Loket 3'),
      ];
    }
  }

  /// Mengambil tiket antrean baru untuk mahasiswa via RPC Stored Procedure
  Future<QueueModel> takeQueueTicket({
    required String serviceId,
    required String studentName,
    required String studentNpm,
    required String studyProgram,
  }) async {
    try {
      // 1. Panggil RPC aman atomic di PostgreSQL
      final response = await _client.rpc('take_queue_ticket', params: {
        'p_service_id': serviceId,
        'p_student_name': studentName.trim(),
        'p_student_npm': studentNpm.trim(),
        'p_study_program': studyProgram.trim(),
      });

      if (response != null && response is Map) {
        final success = response['success'] as bool? ?? false;
        final message = response['message']?.toString() ?? 'Terjadi kesalahan sistem';

        if (!success) {
          throw Exception(message);
        }

        final ticketData = response['data'] as Map<String, dynamic>;
        return QueueModel.fromMap(ticketData);
      } else {
        throw Exception('Respon dari server tidak valid');
      }
    } on PostgrestException catch (e) {
      developer.log('Postgrest error in takeQueueTicket: ${e.message}', name: 'QueueRepository');
      // Jika RPC belum dieksekusi di Supabase, fallback ke direct insert
      return _fallbackDirectInsert(
        serviceId: serviceId,
        studentName: studentName,
        studentNpm: studentNpm,
        studyProgram: studyProgram,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fallback direct insert jika RPC database belum dibuat oleh pengguna
  Future<QueueModel> _fallbackDirectInsert({
    required String serviceId,
    required String studentName,
    required String studentNpm,
    required String studyProgram,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    // Hitung antrean hari ini
    final countRes = await _client
        .from('queues')
        .select('sequence_number')
        .eq('service_id', serviceId)
        .eq('queue_date', today);

    final nextSeq = (countRes as List).length + 1;
    final service = (await getServices()).firstWhere((s) => s.id == serviceId);
    final queueNum = '${service.code}-${nextSeq.toString().padLeft(3, '0')}';

    final insertRes = await _client.from('queues').insert({
      'service_id': serviceId,
      'queue_number': queueNum,
      'sequence_number': nextSeq,
      'student_name': studentName,
      'student_npm': studentNpm,
      'student_study_program': studyProgram,
      'status': 'waiting',
      'queue_date': today,
    }).select().single();

    return QueueModel.fromMap(insertRes);
  }

  /// Mengambil data tiket berdasarkan ID
  Future<QueueModel?> getTicketById(String id) async {
    try {
      final response = await _client
          .from('queues')
          .select('*, services(*)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return QueueModel.fromMap(response);
    } catch (e) {
      developer.log('Error fetching ticket by id: $e', name: 'QueueRepository');
      return null;
    }
  }

  /// Mencari tiket aktif mahasiswa hari ini berdasarkan NPM
  Future<QueueModel?> getTodayActiveTicketByNpm(String npm) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _client
          .from('queues')
          .select('*, services(*)')
          .eq('student_npm', npm.trim())
          .eq('queue_date', today)
          .inFilter('status', ['waiting', 'called', 'in_service'])
          .order('created_at', ascending: false)
          .maybeSingle();

      if (response == null) return null;
      return QueueModel.fromMap(response);
    } catch (e) {
      developer.log('Error fetching active ticket by npm: $e', name: 'QueueRepository');
      return null;
    }
  }

  /// Menghitung berapa banyak nomor antrean di depan tiket mahasiswa
  Future<int> countWaitingAhead(String serviceId, int sequenceNumber) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _client
          .from('queues')
          .select('id')
          .eq('service_id', serviceId)
          .eq('queue_date', today)
          .eq('status', 'waiting')
          .lt('sequence_number', sequenceNumber);

      return (response as List).length;
    } catch (e) {
      developer.log('Error counting waiting ahead: $e', name: 'QueueRepository');
      return 0;
    }
  }

  /// Mengambil seluruh antrean hari ini (untuk papan pantau & dashboard petugas)
  Future<List<QueueModel>> getTodayQueues({String? serviceId, String? status}) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      var query = _client
          .from('queues')
          .select('*, services(*)')
          .eq('queue_date', today);

      if (serviceId != null && serviceId.isNotEmpty) {
        query = query.eq('service_id', serviceId);
      }
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query.order('sequence_number', ascending: true);
      return (response as List).map((json) => QueueModel.fromMap(json)).toList();
    } catch (e) {
      developer.log('Error fetching today queues: $e', name: 'QueueRepository');
      return [];
    }
  }

  /// Mengambil nomor antrean yang sedang dipanggil / aktif saat ini per loket
  Future<List<QueueModel>> getCurrentlyServingQueues() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _client
          .from('queues')
          .select('*, services(*)')
          .eq('queue_date', today)
          .inFilter('status', ['called', 'in_service'])
          .order('called_at', ascending: false);

      return (response as List).map((json) => QueueModel.fromMap(json)).toList();
    } catch (e) {
      developer.log('Error fetching currently serving queues: $e', name: 'QueueRepository');
      return [];
    }
  }

  /// Berlangganan (Subscribe) perubahan realtime untuk tiket spesifik mahasiswa
  RealtimeChannel subscribeToTicket({
    required String ticketId,
    required void Function(QueueModel updated) onUpdate,
  }) {
    final channelName = 'public:queues:id=$ticketId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'queues',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: ticketId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              onUpdate(QueueModel.fromMap(newRecord));
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Berlangganan (Subscribe) perubahan realtime seluruh antrean hari ini
  RealtimeChannel subscribeToAllTodayQueues({
    required void Function() onChange,
  }) {
    final channel = _client.channel('public:queues:all_today');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'queues',
          callback: (payload) {
            onChange();
          },
        )
        .subscribe();

    return channel;
  }

  // ========================================================================
  // OPERASI KHUSUS PETUGAS ULT (MEMERLUKAN AUTHENTICATION SUPABASE)
  // ========================================================================

  /// Petugas memanggil antrean berikutnya yang berstatus 'waiting'
  Future<QueueModel?> staffCallNextQueue({
    required String serviceId,
    required String counterName,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final staffId = _client.auth.currentUser?.id;

    // Cari tiket waiting dengan urutan terkecil
    final nextWaiting = await _client
        .from('queues')
        .select()
        .eq('service_id', serviceId)
        .eq('queue_date', today)
        .eq('status', 'waiting')
        .order('sequence_number', ascending: true)
        .limit(1)
        .maybeSingle();

    if (nextWaiting == null) {
      return null;
    }

    final ticketId = nextWaiting['id'].toString();

    // Update status menjadi 'called'
    final updated = await _client.from('queues').update({
      'status': 'called',
      'counter_name': counterName,
      'called_by': staffId,
      'called_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId).select('*, services(*)').single();

    return QueueModel.fromMap(updated);
  }

  /// Petugas memperbarui status antrean ('in_service', 'completed', 'skipped')
  Future<bool> staffUpdateQueueStatus({
    required String queueId,
    required String newStatus,
    String? counterName,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final Map<String, dynamic> updateData = {
        'status': newStatus,
      };

      if (counterName != null) {
        updateData['counter_name'] = counterName;
      }

      if (newStatus == 'in_service') {
        updateData['served_at'] = now;
      } else if (newStatus == 'completed') {
        updateData['completed_at'] = now;
      } else if (newStatus == 'called') {
        updateData['called_at'] = now;
      }

      await _client.from('queues').update(updateData).eq('id', queueId);
      return true;
    } catch (e) {
      developer.log('Error updating queue status: $e', name: 'QueueRepository');
      return false;
    }
  }
}
