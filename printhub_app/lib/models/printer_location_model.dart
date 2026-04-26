class PrinterLocationModel {
  final String id;
  final String name;
  final String description;
  final bool isOnline;

  const PrinterLocationModel({
    required this.id,
    required this.name,
    this.description = '',
    this.isOnline = false,
  });

  factory PrinterLocationModel.fromJson(Map<String, dynamic> json) =>
      PrinterLocationModel(
        id:          json['_id']         ?? '',
        name:        json['name']        ?? '',
        description: json['description'] ?? '',
        isOnline:    json['isOnline']    ?? false,
      );
}
