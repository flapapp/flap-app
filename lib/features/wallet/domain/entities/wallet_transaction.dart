class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final String? description;
  final DateTime createdAt;
}
