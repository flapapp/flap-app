import 'package:equatable/equatable.dart';

/// Domain-level admin action error for UI mapping.
class AdminFailure extends Equatable implements Exception {
  const AdminFailure({required this.code, this.message});

  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];

  @override
  String toString() => 'AdminFailure($code, $message)';
}
