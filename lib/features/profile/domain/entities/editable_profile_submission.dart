import 'dart:typed_data';

/// Create / edit profile form payload (domain).
class EditableProfileSubmission {
  const EditableProfileSubmission({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.city,
    this.dateOfBirth,
    this.position,
    this.avatarJpegBytes,
    this.isEditing = false,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String city;
  /// Calendar date only (year, month, day); persisted as [profiles.dat_of_birth].
  final DateTime? dateOfBirth;
  final String? position;
  final Uint8List? avatarJpegBytes;
  final bool isEditing;
}
