class WalletTransactionModel {
  final String id;
  final String studentId;
  final int    amount;
  final String type;        // 'credit' or 'debit'
  final String description;
  final String addedBy;
  final String addedByRole;
  final double balanceAfter;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.type,
    this.description = '',
    this.addedBy = '',
    this.addedByRole = '',
    this.balanceAfter = 0,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) =>
      WalletTransactionModel(
        id:           json['_id']          ?? '',
        studentId:    json['studentId']    ?? '',
        amount:       (json['amount']      ?? 0).toInt(),
        type:         json['type']         ?? 'credit',
        description:  json['description']  ?? '',
        addedBy:      json['addedBy']      ?? '',
        addedByRole:  json['addedByRole']  ?? '',
        balanceAfter: (json['balanceAfter'] ?? 0).toDouble(),
        createdAt:    json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );

  bool get isCredit => type == 'credit';
}
