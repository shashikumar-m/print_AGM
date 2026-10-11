class SectionModel {
  final String id;
  final String name;
  final String assignedPrinterId;

  const SectionModel({
    required this.id,
    required this.name,
    this.assignedPrinterId = '',
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) => SectionModel(
        id:                json['_id']               ?? '',
        name:              json['name']              ?? '',
        assignedPrinterId: json['assignedPrinterId'] ?? '',
      );
}
