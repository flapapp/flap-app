import 'dart:typed_data';

/// Create / edit profile form payload (domain).
class EditableProfileSubmission {
  const EditableProfileSubmission({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.city,
    this.age,
    this.position,
    this.experience,
    this.avatarJpegBytes,
    this.isEditing = false,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String city;
  final int? age;
  final String? position;
  final String? experience;
  final Uint8List? avatarJpegBytes;
  final bool isEditing;
}
