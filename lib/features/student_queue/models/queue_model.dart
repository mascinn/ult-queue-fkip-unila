import 'service_model.dart';

class QueueModel {
  final String id;
  final String serviceId;
  final String queueNumber;
  final int sequenceNumber;
  final String studentName;
  final String studentNpm;
  final String studentStudyProgram;
  final String status; // 'waiting', 'called', 'in_service', 'completed', 'skipped'
  final String? counterName;
  final String? calledBy;
  final String queueDate;
  final DateTime? calledAt;
  final DateTime? servedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final ServiceModel? service;

  QueueModel({
    required this.id,
    required this.serviceId,
    required this.queueNumber,
    required this.sequenceNumber,
    required this.studentName,
    required this.studentNpm,
    required this.studentStudyProgram,
    required this.status,
    this.counterName,
    this.calledBy,
    required this.queueDate,
    this.calledAt,
    this.servedAt,
    this.completedAt,
    required this.createdAt,
    this.service,
  });

  bool get isWaiting => status.toLowerCase() == 'waiting';
  bool get isCalled => status.toLowerCase() == 'called';
  bool get isInService => status.toLowerCase() == 'in_service';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isSkipped => status.toLowerCase() == 'skipped';

  String get statusDisplayIndonesian {
    switch (status.toLowerCase()) {
      case 'called':
        return 'Dipanggil';
      case 'in_service':
        return 'Sedang Dilayani';
      case 'completed':
        return 'Selesai';
      case 'skipped':
        return 'Dilewati';
      case 'waiting':
      default:
        return 'Menunggu';
    }
  }

  factory QueueModel.fromMap(Map<String, dynamic> map) {
    return QueueModel(
      id: map['id']?.toString() ?? '',
      serviceId: map['service_id']?.toString() ?? '',
      queueNumber: map['queue_number']?.toString() ?? '',
      sequenceNumber: (map['sequence_number'] as num?)?.toInt() ?? 0,
      studentName: map['student_name']?.toString() ?? '',
      studentNpm: map['student_npm']?.toString() ?? '',
      studentStudyProgram: map['student_study_program']?.toString() ?? '',
      status: map['status']?.toString() ?? 'waiting',
      counterName: map['counter_name']?.toString(),
      calledBy: map['called_by']?.toString(),
      queueDate: map['queue_date']?.toString() ?? '',
      calledAt: map['called_at'] != null ? DateTime.tryParse(map['called_at'].toString()) : null,
      servedAt: map['served_at'] != null ? DateTime.tryParse(map['served_at'].toString()) : null,
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'].toString()) : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      service: map['services'] != null ? ServiceModel.fromMap(map['services'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'service_id': serviceId,
      'queue_number': queueNumber,
      'sequence_number': sequenceNumber,
      'student_name': studentName,
      'student_npm': studentNpm,
      'student_study_program': studentStudyProgram,
      'status': status,
      'counter_name': counterName,
      'called_by': calledBy,
      'queue_date': queueDate,
      'called_at': calledAt?.toIso8601String(),
      'served_at': servedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  QueueModel copyWith({
    String? status,
    String? counterName,
    DateTime? calledAt,
    DateTime? servedAt,
    DateTime? completedAt,
  }) {
    return QueueModel(
      id: id,
      serviceId: serviceId,
      queueNumber: queueNumber,
      sequenceNumber: sequenceNumber,
      studentName: studentName,
      studentNpm: studentNpm,
      studentStudyProgram: studentStudyProgram,
      status: status ?? this.status,
      counterName: counterName ?? this.counterName,
      calledBy: calledBy,
      queueDate: queueDate,
      calledAt: calledAt ?? this.calledAt,
      servedAt: servedAt ?? this.servedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      service: service,
    );
  }
}
