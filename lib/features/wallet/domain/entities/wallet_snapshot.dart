class WalletSnapshot {
  const WalletSnapshot({
    required this.id,
    required this.userId,
    required this.balance,
    required this.lockedBalance,
    required this.currency,
    required this.totalEarned,
    required this.totalSpent,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final double balance;
  final double lockedBalance;
  final String currency;
  final double totalEarned;
  final double totalSpent;
  final String status;
  final DateTime updatedAt;
}
