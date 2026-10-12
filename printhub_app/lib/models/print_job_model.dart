class PrintJobModel {
  final String id;
  final String userId;
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
  final String printerLocationName;
  final DateTime createdAt;

  const PrintJobModel({
    required this.id,
    this.userId = '',
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
    this.printerLocationName = '',
    required this.createdAt,
  });

  factory PrintJobModel.fromJson(Map<String, dynamic> json) => PrintJobModel(
        id:                   json['_id']                  ?? '',
        userId:               json['userId']               ?? '',
        studentName:          json['studentName']          ?? json['userName'] ?? '',
        studentSection:       json['studentSection']       ?? json['userSection'] ?? '',
        fileName:             json['fileName']             ?? '',
        pages:                (json['pages']               ?? 0).toInt(),
        cost:                 (json['cost']                ?? 0).toDouble(),
        status:               json['status']               ?? 'pending',
        duplex:               json['duplex']               ?? false,
        colorMode:            json['colorMode']            ?? 'bw',
        pageRangeFrom:        (json['pageRangeFrom']       ?? 0).toInt(),
        pageRangeTo:          (json['pageRangeTo']         ?? 0).toInt(),
        pagesPerSheet:        (json['pagesPerSheet']       ?? 1).toInt(),
        printerLocationName:  json['printerLocationName']  ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );

  bool get isPending   => status == 'pending';
  bool get isPrinting  => status == 'printing';
  bool get isCompleted => status == 'completed';
  bool get isFailed    => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive    => isPending || isPrinting;
}
