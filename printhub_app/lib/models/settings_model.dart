class SettingsModel {
  final double pricePerPage;
  final bool allowColor;
  final bool allowDuplex;
  final bool allowPageRange;
  final bool allowPagesPerSheet;
  final int maxPagesPerJob;

  const SettingsModel({
    this.pricePerPage = 1,
    this.allowColor = true,
    this.allowDuplex = true,
    this.allowPageRange = true,
    this.allowPagesPerSheet = true,
    this.maxPagesPerJob = 0,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        pricePerPage:       (json['pricePerPage']       ?? 1).toDouble(),
        allowColor:          json['allowColor']         ?? true,
        allowDuplex:         json['allowDuplex']        ?? true,
        allowPageRange:      json['allowPageRange']     ?? true,
        allowPagesPerSheet:  json['allowPagesPerSheet'] ?? true,
        maxPagesPerJob:     (json['maxPagesPerJob']     ?? 0).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'pricePerPage':       pricePerPage,
        'allowColor':         allowColor,
        'allowDuplex':        allowDuplex,
        'allowPageRange':     allowPageRange,
        'allowPagesPerSheet': allowPagesPerSheet,
        'maxPagesPerJob':     maxPagesPerJob,
      };
}
