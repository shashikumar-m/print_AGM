class PrintJobModel {
  final String id;
  final String studentName;
  final String fileName;
  final int pages;
  final double cost;
  final String status;
  final bool duplex;
  final DateTime createdAt;

  PrintJobModel({
    required this.id,
    required this.studentName,
    required this.fileName,
    required this.pages,
    required this.cost,
    required this.status,
    required this.duplex,
    required this.createdAt,
  });

  factory PrintJobModel.fromJson(Map<String, dynamic> json) {
    return PrintJobModel(
      id: json['_id'] ?? '',
      studentName: json['studentName'] ?? '',
      fileName: json['fileName'] ?? '',
      pages: (json['pages'] ?? 0).toInt(),
      cost: (json['cost'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      duplex: json['duplex'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
