class ServiceModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int quotaPerDay;
  final bool isActive;

  ServiceModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.quotaPerDay = 50,
    this.isActive = true,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      quotaPerDay: (map['quota_per_day'] as num?)?.toInt() ?? 50,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'quota_per_day': quotaPerDay,
      'is_active': isActive,
    };
  }
}
