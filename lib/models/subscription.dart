import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionPlan { free, champions }

class Subscription {
  final String userId;
  final SubscriptionPlan plan;
  final DateTime startAt;
  final DateTime endAt;
  final bool autoRenew;

  const Subscription({
    required this.userId,
    required this.plan,
    required this.startAt,
    required this.endAt,
    this.autoRenew = false,
  });

  bool get isActive => DateTime.now().isBefore(endAt);
  DateTime get endDate => endAt; // Alias for compatibility

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'plan': plan.name,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'autoRenew': autoRenew,
      };

  factory Subscription.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Subscription(
      userId: d['userId'] ?? '',
      plan: SubscriptionPlan.values.firstWhere(
        (p) => p.name == (d['plan'] ?? 'free'),
        orElse: () => SubscriptionPlan.free,
      ),
      startAt: (d['startAt'] as Timestamp).toDate(),
      endAt: (d['endAt'] as Timestamp).toDate(),
      autoRenew: d['autoRenew'] ?? false,
    );
  }
}


