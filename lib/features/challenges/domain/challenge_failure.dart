import 'package:equatable/equatable.dart';

/// Domain-level challenge / submission / vote errors for UI mapping.
class ChallengeFailure extends Equatable implements Exception {
  const ChallengeFailure({required this.code, this.message});

  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];

  @override
  String toString() => 'ChallengeFailure($code, $message)';
}
