import 'package:equatable/equatable.dart';

/// Domain-level auth error for UI mapping.
class AuthFailure extends Equatable implements Exception {
  const AuthFailure({required this.code, this.message});

  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];

  @override
  String toString() => 'AuthFailure($code, $message)';
}
