class PrintJobModel {
  final String id;
  final String studentName;
  final String studentSection;
  final String fileName;
  final int pages;
  final double cost;
  final String status;
  final bool duplex;
  final String colorMode;
  final int pageRangeFrom;
  final int pageRangeTo;
  final int pagesPerSheet;
  final DateTime createdAt;

  const PrintJobModel({
    required this.id,
    required this.studentName,
    this.studentSection = '',
    required this.fileName,
    required this.pages,
    required this.cost,
    required this.status,
    required this.duplex,
    this.colorMode = 'bw',
    this.pageRangeFrom = 0,
    this.pageRangeTo = 0,
    this.pagesPerSheet = 1,
    required this.createdAt,
  });

  factory PrintJobModel.fromJson(Map<String, dynamic> json) => PrintJobModel(
        id:             json['_id']            ?? '',
        studentName:    json['studentName']    ?? '',
        studentSection: json['studentSection'] ?? '',
        fileName:       json['fileName']       ?? '',
        pages:          (json['pages']         ?? 0).toInt(),
        cost:           (json['cost']          ?? 0).toDouble(),
        status:         json['status']         ?? 'pending',
        duplex:         json['duplex']         ?? false,
        colorMode:      json['colorMode']      ?? 'bw',
        pageRangeFrom:  (json['pageRangeFrom'] ?? 0).toInt(),
        pageRangeTo:    (json['pageRangeTo']   ?? 0).toInt(),
        pagesPerSheet:  (json['pagesPerSheet'] ?? 1).toInt(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );
}
