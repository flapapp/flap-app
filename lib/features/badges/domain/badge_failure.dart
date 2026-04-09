import 'package:equatable/equatable.dart';

/// Domain-level badge / wallet error for UI mapping.
class BadgeFailure extends Equatable implements Exception {
  const BadgeFailure({required this.code, this.message});

  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];

  @override
  String toString() => 'BadgeFailure($code, $message)';
}
