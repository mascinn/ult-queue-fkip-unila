class CounterModel {
  final int id;
  final String name;
  final bool isActive;

  CounterModel({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  factory CounterModel.fromMap(Map<String, dynamic> map) {
    return CounterModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
