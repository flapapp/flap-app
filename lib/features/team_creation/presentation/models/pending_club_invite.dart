import 'package:equatable/equatable.dart';

class PendingClubInvite extends Equatable {
  const PendingClubInvite({
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;

  @override
  List<Object?> get props => [userId, displayName];
}
