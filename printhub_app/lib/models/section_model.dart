class SectionModel {
  final String id;
  final String name;

  const SectionModel({required this.id, required this.name});

  factory SectionModel.fromJson(Map<String, dynamic> json) => SectionModel(
        id:   json['_id'] ?? '',
        name: json['name'] ?? '',
      );
}
